library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.xtcpkg.all;
use work.wishbonepkg.all;
-- synthesis translate_off
use work.txt_util.all;
-- synthesis translate_on

entity icache is
  generic (
      ADDRESS_HIGH: integer := 31
  );
  port (
    syscon:         in wb_syscon_type;

    valid:          out std_logic;
    data:           out std_logic_vector(31 downto 0);
    address:        in std_logic_vector(31 downto 0);
    strobe:         in std_logic;
    enable:         in std_logic;
    seq:            in std_logic;
    stall:          out std_logic;
    flush:          in std_logic;
    abort:          in std_logic;

    tag:            in std_logic_vector(31 downto 0);
    tagen:          in std_logic;

    -- Master wishbone interface
    mwbo:           out wb_mosi_type;
    mwbi:           in  wb_miso_type
  );
end icache;

architecture behave of icache is
  
  constant ADDRESS_LOW: integer := 0;
  constant CACHE_MAX_BITS: integer := 13; -- 8 Kb
  constant CACHE_LINE_SIZE_BITS: integer := 6; -- 64 bytes
  constant CACHE_LINE_SIZE: integer := 2**CACHE_LINE_SIZE_BITS;

  constant CACHE_LINE_ID_BITS: integer := CACHE_MAX_BITS-CACHE_LINE_SIZE_BITS;

-- memory max width: 19 bits (18 downto 0)
-- cache line size: 64 bytes
-- cache lines: 128



  alias line: std_logic_vector(CACHE_LINE_ID_BITS-1 downto 0)
    is address(CACHE_MAX_BITS-1 downto CACHE_LINE_SIZE_BITS);

  alias line_offset: std_logic_vector(CACHE_LINE_SIZE_BITS-1 downto 2)
    is address(CACHE_LINE_SIZE_BITS-1 downto 2);

  signal ctag: std_logic_vector(ADDRESS_HIGH-CACHE_MAX_BITS+1 downto 0);

  signal miss: std_logic;
  signal ack: std_logic;

  type state_type is (
    flushing,
    running,
    filling,
    --waitwrite,
    ending
  );

  constant offcnt_zero: unsigned(line_offset'HIGH downto 2) := (others => '0');

  signal tag_match: std_logic;
  signal cache_addr_read,cache_addr_write: std_logic_vector(CACHE_MAX_BITS-1 downto 2);


  signal access_i: std_logic;
  signal stall_i, valid_i: std_logic;
  signal hit: std_logic;
  signal tag_mem_enable: std_logic;
  signal cache_mem_enable: std_logic;
  signal exttag_save: std_logic_vector(ADDRESS_HIGH-CACHE_MAX_BITS downto 0);
  signal tag_mem_data: std_logic_vector(ADDRESS_HIGH-CACHE_MAX_BITS+1 downto 0);
  signal tag_mem_addr: std_logic_vector(CACHE_LINE_ID_BITS-1 downto 0);

  constant dignore: std_logic_vector(ctag'RANGE) := (others => DontCareValue);
  constant dignore32: std_logic_vector(31 downto 0) := (others => DontCareValue);

  signal valid_while_filling: std_logic;

  type icache_regs_type is record
    cyc, stb:     std_logic;
    busy:         std_logic;
    state:        state_type;
    fill_success: std_logic;
    flushcnt:     unsigned(line'RANGE);
    tag_mem_wen:  std_logic;
    wbaddr:       std_logic_vector(31 downto CACHE_MAX_BITS);
    offcnt:       unsigned(line_offset'HIGH downto 2);
    offcnt_write: unsigned(line_offset'HIGH downto 2);
    stbcount:     unsigned(line_offset'HIGH downto 2);
    access_q:     std_logic;
    queued_address: std_logic;
    save_addr:    std_logic_vector(address'RANGE);
    line_save:    std_logic_vector(CACHE_LINE_ID_BITS-1 downto 0);
    tag_save: std_logic_vector(ADDRESS_HIGH-CACHE_MAX_BITS downto 0);
    enable_q:     std_logic;
    iwfready:     std_logic;
    fault:        std_logic;
    flush:        std_logic;
  end record;

  signal r: icache_regs_type;

  alias tag_save: std_logic_vector(ADDRESS_HIGH-CACHE_MAX_BITS downto 0)
    is r.save_addr(ADDRESS_HIGH downto CACHE_MAX_BITS);

  alias address_tag: std_logic_vector(ADDRESS_HIGH-CACHE_MAX_BITS downto 0)
    is r.save_addr(ADDRESS_HIGH downto CACHE_MAX_BITS);

  signal ctag_address: std_logic_vector(address_tag'RANGE);

  signal wrcachea: std_logic;

  signal cmem_enable: std_logic;
  signal cmem_wren:   std_logic;

  signal access_to_same_line: std_logic;

begin

  ctag_address<=ctag(address_tag'HIGH downto address_tag'LOW);

  tagmem: entity work.generic_dp_ram_1r1w
  generic map (
    address_bits  => CACHE_LINE_ID_BITS,
    data_bits     => ADDRESS_HIGH-CACHE_MAX_BITS+2
  )
  port map (
    clka      => syscon.clk,
    ena       => tag_mem_enable,
    addra     => cache_addr_read(CACHE_MAX_BITS-1 downto CACHE_LINE_SIZE_BITS),--line,
    doa       => ctag,

    clkb      => syscon.clk,
    enb       => '1',
    web       => r.tag_mem_wen,
    addrb     => tag_mem_addr,
    dib       => tag_mem_data,
    dob       => open
  );

  cachemem: entity work.generic_dp_ram_1r1w
  generic map (
    address_bits => cache_addr_read'LENGTH,
    data_bits => 32
  )
  port map (
    clka      => syscon.clk,
    ena       => cache_mem_enable,
    addra     => cache_addr_read,
    doa       => data,

    clkb      => syscon.clk,
    enb       => cmem_enable,
    web       => cmem_wren,
    addrb     => cache_addr_write,
    dib       => mwbi.dat,
    dob       => open
  );

  cmem_enable <= '1';
  cmem_wren <= mwbi.ack;

  valid_i <= ctag(ctag'HIGH);

  process(r.state, r.flushcnt, tagen, exttag_save)
    variable wrtag: std_logic_vector(ADDRESS_HIGH-CACHE_MAX_BITS downto 0);

  begin
    if tagen='1' then
    wrtag := exttag_save;
    else
    wrtag := tag_save;
    end if;
    if r.state=flushing then
      tag_mem_data <= '0' & wrtag;
      tag_mem_addr <= std_logic_vector(r.flushcnt);
    else
      tag_mem_data <= '1' & wrtag;
      tag_mem_addr <= r.line_save;
    end if;
  end process;


  process(ctag_address, address_tag, tag, tagen)
  begin
    if tagen='0' then
      if ctag_address=address_tag then
        tag_match<='1';
      else
        tag_match<='0';
      end if;
    else
      if ctag_address=tag(ADDRESS_HIGH downto CACHE_MAX_BITS) then
        tag_match<='1';
      else
        tag_match<='0';
      end if;

    end if;
  end process;

  cache_addr_write <= r.line_save & mwbi.tag(CACHE_LINE_SIZE_BITS-3 downto 0);

  access_to_same_line<='1' when r.line_save = r.save_addr(CACHE_MAX_BITS-1 downto CACHE_LINE_SIZE_BITS) and
          r.tag_save = r.save_addr(ADDRESS_HIGH downto CACHE_MAX_BITS) else '0';

  process(r,strobe,enable,miss,syscon,line,line_offset,hit,flush,mwbi,valid_while_filling,abort)
    variable ett: std_logic_vector(exttag_save'RANGE);
    variable w: icache_regs_type;
    variable data_valid: std_logic;
    variable stall_input: std_logic;
  begin

    w:=r;

    w.busy := '0';
    w.cyc := '0';
   -- w.stb := 'X';
    w.tag_mem_wen := '0';
    w.fill_success :='0';
    w.flushcnt := (others => 'X');

    data_valid := '0';
    tag_mem_enable <= enable and strobe;
    cache_mem_enable <= enable and strobe;
    cache_addr_read <= line & line_offset;

    case r.state is

      when flushing =>
        w.busy := '1';
        w.flushcnt := r.flushcnt - 1;
        w.tag_mem_wen := '1';
        w.wbaddr(31 downto CACHE_MAX_BITS) := (others => 'X');
        w.offcnt := (others => 'X');
        w.offcnt_write := (others => 'X');
        w.iwfready := '0';
        stall_input := '1';

        if r.flushcnt=0 then
          w.tag_mem_wen:='0';
          --w.state := running;
        if r.queued_address='1' and r.fault='1' then
          w.state := filling;
          w.wbaddr(31 downto CACHE_MAX_BITS) := r.save_addr(31 downto CACHE_MAX_BITS);
          w.state := filling;
          w.offcnt(CACHE_LINE_SIZE_BITS-1 downto 2) := unsigned(r.save_addr(CACHE_LINE_SIZE_BITS-1 downto 2));
          w.offcnt_write  := (others => '1');
          w.stbcount      := (others => '1');
          w.cyc   := '1';
          w.stb   := '1';
          w.busy  := '1';
          w.queued_address:='0';
          w.line_save := r.save_addr(CACHE_MAX_BITS-1 downto CACHE_LINE_SIZE_BITS);
          w.tag_save := r.save_addr(ADDRESS_HIGH downto CACHE_MAX_BITS);

        else
          w.state := running;
        end if;

        end if;

      when running =>

        w.offcnt := (others => 'X');
        w.offcnt_write := (others => 'X');
        w.wbaddr(31 downto CACHE_MAX_BITS) := (others => 'X');
        w.iwfready:='0';
        stall_input := '0';

        data_valid := hit;
        w.stb := 'X';
        if r.access_q='1' then
          -- We had a cache access in last clock cycle.
          if r.enable_q='1' then

            if miss='1' and abort='0' then -- And it was a miss...
              stall_input := '1';
              data_valid := '0';

              w.wbaddr(31 downto CACHE_MAX_BITS) := r.save_addr(31 downto CACHE_MAX_BITS);
              w.state := filling;

              w.offcnt(CACHE_LINE_SIZE_BITS-1 downto 2) := unsigned(r.save_addr(CACHE_LINE_SIZE_BITS-1 downto 2));
              w.offcnt_write  := (others => '1');
              w.stbcount      := (others => '1');

              w.cyc   := '1';
              w.stb   := '1';
              w.busy  := '1';
            else
              data_valid := '1';
            end if;
          end if;
        end if;

        if flush='1' then
          w.state := flushing;
          w.flushcnt := (others => '1');
          w.tag_mem_wen := '1';
          -- TODO: check if this is correct...
          stall_input:='1';
        end if;

        w.queued_address := '0';
        if r.access_q='1' and data_valid='0' then
          w.queued_address:='1';
        else
          w.queued_address:='0';
        end if;

        w.fault := '0';

      when filling =>
        stall_input := '1';
        w.busy:= '1';
        w.cyc := '1';
        tag_mem_enable    <= '1';
        cache_mem_enable  <= enable and strobe;

        if mwbi.ack='1' then
          w.iwfready := enable;
          w.offcnt_write := r.offcnt_write - 1;
          -- This will go to 0, but we check before and switch state
          if r.offcnt_write=offcnt_zero then
            w.tag_mem_wen := '1';
            w.state := ending;
          end if;
        end if;
          
        if mwbi.stall='0' then
          w.offcnt := r.offcnt + 1;
          -- this needed ??
          if r.stbcount/=offcnt_zero then
            w.stbcount := w.stbcount - 1;
          else
            w.stb := '0';
          end if;
        end if;

        if true then

          if r.iwfready='0' then
            cache_addr_read <= r.save_addr(CACHE_MAX_BITS-1 downto 2);
          end if;

          if enable='1' then
            stall_input := not r.iwfready;
            data_valid := r.iwfready;

            if r.iwfready='1' and strobe='1' then
              w.iwfready:='0';
            end if;
            if seq='0' and strobe='1' and stall_input='0' then
              --stall_input := '1';
              data_valid:='0';
              w.fault :='1';
            end if;

            if r.access_q='1' and access_to_same_line='0' then
              data_valid:='0';
              stall_input:='1';
              w.fault := '1';
            end if;
          end if;

          if r.fault='1' then
            stall_input:='1';
            data_valid:='0';
          end if;

          if stall_input='0' then
            if enable='1' and strobe='1' then
              w.queued_address:='1';
            else
              w.queued_address:='0';
            end if;
          end if;

          if flush='1' then
            w.fault:='1';
            data_valid:='0';
            stall_input:='1';
            w.flush:='1';
          end if;

          if stall_input='0' then
            if enable='1' and strobe='1' then
              w.queued_address:='1';
            else
              w.queued_address:='0';
            end if;
          end if;

          if abort='1' then
            w.fault:='1';
          end if;

        end if;  -- IWF

      when ending =>
        w.busy :='0';
        w.wbaddr(31 downto CACHE_MAX_BITS) := (others => 'X');
        w.offcnt := (others => 'X');
        w.offcnt_write := (others => 'X');
        w.stbcount :=     (others => 'X');
        w.line_save:=     (others => 'X');
        w.tag_save:=     (others => 'X');
        w.iwfready:='0';
        tag_mem_enable <= '1';
        cache_mem_enable <='1';
        cache_addr_read <= r.save_addr(CACHE_MAX_BITS-1 downto 2);

        stall_input := '1';
        w.fault:='0';

        if enable='1' then
          w.fill_success := '1';
        end if;

        if r.queued_address='1' then--and r.fault='1' then
          w.state := filling;
          w.cyc   := '1';
          w.stb   := '1';
          w.busy  := '1';
          w.queued_address:='0';
          w.wbaddr(31 downto CACHE_MAX_BITS) := r.save_addr(31 downto CACHE_MAX_BITS);
          w.offcnt(CACHE_LINE_SIZE_BITS-1 downto 2) := unsigned(r.save_addr(CACHE_LINE_SIZE_BITS-1 downto 2));
          w.offcnt_write  := (others => '1');
          w.stbcount      := (others => '1');
          w.line_save := r.save_addr(CACHE_MAX_BITS-1 downto CACHE_LINE_SIZE_BITS);
          w.tag_save := r.save_addr(ADDRESS_HIGH downto CACHE_MAX_BITS);

        else
          w.state := running;
        end if;

        w.flush:='0';

        if r.flush='1' then
          w.state := flushing;
          w.flushcnt := (others => '1');
          w.tag_mem_wen := '1';
          w.cyc :='0';
        end if;

    end case;


    if strobe='1' and enable='1' then
      if stall_input='0' then
        w.save_addr := address;
        w.access_q := '1';
        if r.state=running then
          w.line_save := address(CACHE_MAX_BITS-1 downto CACHE_LINE_SIZE_BITS);
          w.tag_save := address(ADDRESS_HIGH downto CACHE_MAX_BITS);
        end if;
      end if;
    else
      if stall_input='0' then
        w.access_q := '0';
      end if;
    end if;


    if abort='1' then
      w.access_q:='0';
      w.queued_address:='0';
    end if;

    w.enable_q := enable;

    valid <= data_valid;
    stall <= stall_input;

    if syscon.rst='1' then
      w.state := flushing;
      w.busy  := '1';
      w.fill_success :='0';
      w.flushcnt := (others => '1');
      w.tag_mem_wen := '1'; -- this needed ??
      w.cyc := '0';
      w.stb := 'X';
      w.wbaddr(31 downto CACHE_MAX_BITS) := (others => 'X');
      w.offcnt := (others => 'X');
      w.offcnt_write := (others => 'X');
      w.access_q := '0';
      w.enable_q := '0';
      w.queued_address:='0';
      w.iwfready:='0';
      w.flush := '0';
      w.fault := '0';
      w.stbcount :=     (others => 'X');
      w.line_save:=     (others => 'X');
      w.tag_save:=     (others => 'X');

    end if;




    if rising_edge(syscon.clk) then
      r <= w;
    end if;



  end process;

  hit <= '1' when tag_match='1' and valid_i='1' else '0';
  miss <= not hit;
  mwbo.cyc  <= r.cyc;
  mwbo.stb  <= r.stb;
  mwbo.we   <= '0';
  mwbo.dat  <= (others => 'X');
  mwbo.bte  <= BTE_BURST_16BEATWRAP;
  mwbo.cti  <= CTI_CYCLE_INCRADDR; -- BUg: we need to signal eof

  mwbo.adr(31 downto CACHE_MAX_BITS) <= r.wbaddr(31 downto CACHE_MAX_BITS);
  mwbo.adr(CACHE_MAX_BITS-1 downto CACHE_LINE_SIZE_BITS) <= r.line_save;
  mwbo.adr(CACHE_LINE_SIZE_BITS-1 downto 2) <= std_logic_vector(r.offcnt(CACHE_LINE_SIZE_BITS-1 downto 2));

  mwbo.tag(CACHE_LINE_SIZE_BITS-3 downto 0) <= std_logic_vector(r.offcnt(CACHE_LINE_SIZE_BITS-1 downto 2));

  mwbo.adr(1 downto 0) <= "00";

end behave;
