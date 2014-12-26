library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.xtcpkg.all;
use work.xtccomppkg.all;
-- synthesis translate_off
use work.txt_util.all;
-- synthesis translate_on

entity icache is
  generic (
      ADDRESS_HIGH: integer := 31
  );
  port (
    wb_clk_i:       in std_logic;
    wb_rst_i:       in std_logic;

    valid:          out std_logic;
    data:           out std_logic_vector(31 downto 0);
    address:        in std_logic_vector(31 downto 0);
    strobe:         in std_logic;
    enable:         in std_logic;
    stall:          out std_logic;
    flush:          in std_logic;
    abort:          in std_logic;

    tag:            in std_logic_vector(31 downto 0);
    tagen:          in std_logic;
    -- Master wishbone interface

    m_wb_ack_i:       in std_logic;
    m_wb_dat_i:       in std_logic_vector(31 downto 0);
    m_wb_dat_o:       out std_logic_vector(31 downto 0);
    m_wb_adr_o:       out std_logic_vector(31 downto 0);
    m_wb_cyc_o:       out std_logic;
    m_wb_stb_o:       out std_logic;
    m_wb_stall_i:     in std_logic;
    m_wb_we_o:        out std_logic
  );
end icache;

architecture behave of icache is
  
  constant ADDRESS_LOW: integer := 0;
  constant CACHE_MAX_BITS: integer := 13; -- 8 Kb
  constant CACHE_LINE_SIZE_BITS: integer := 6; -- 64 bytes
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
    waitwrite,
    ending
  );

  constant offcnt_full: unsigned(line_offset'HIGH downto 2) := (others => '1');

  signal tag_match: std_logic;
  signal cache_addr_read,cache_addr_write:
    std_logic_vector(CACHE_MAX_BITS-1 downto 2);


  signal access_i: std_logic;
  signal stall_i, valid_i: std_logic;
  signal hit: std_logic;
  signal tag_mem_enable: std_logic;
  signal exttag_save: std_logic_vector(ADDRESS_HIGH-CACHE_MAX_BITS downto 0);
  signal tag_mem_data: std_logic_vector(ADDRESS_HIGH-CACHE_MAX_BITS+1 downto 0);
  signal tag_mem_addr: std_logic_vector(CACHE_LINE_ID_BITS-1 downto 0);

  constant dignore: std_logic_vector(ctag'RANGE) := (others => DontCareValue);
  constant dignore32: std_logic_vector(31 downto 0) := (others => DontCareValue);

  signal loadsave: std_logic;
  signal valid_while_filling: std_logic;

  type icache_regs_type is record
    cyc, stb:     std_logic;
    busy:         std_logic;
    state:        state_type;
    fill_success: std_logic;
    flushcnt:     unsigned(line'RANGE);
    tag_mem_wen:  std_logic;
    wbaddr:       std_logic_vector(31 downto 0);
    offcnt:       unsigned(line_offset'HIGH+1 downto 2);
    offcnt_write: unsigned(line_offset'HIGH downto 2);
    access_q:     std_logic;
    queued_address: std_logic;
    save_addr:    std_logic_vector(address'RANGE);

  end record;

  signal r: icache_regs_type;

  alias tag_save: std_logic_vector(ADDRESS_HIGH-CACHE_MAX_BITS downto 0)
    is r.save_addr(ADDRESS_HIGH downto CACHE_MAX_BITS);

  alias line_save: std_logic_vector(CACHE_LINE_ID_BITS-1 downto 0)
    is r.save_addr(CACHE_MAX_BITS-1 downto CACHE_LINE_SIZE_BITS);

  alias address_tag: std_logic_vector(ADDRESS_HIGH-CACHE_MAX_BITS downto 0)
    is r.save_addr(ADDRESS_HIGH downto CACHE_MAX_BITS);

  signal ctag_address: std_logic_vector(address_tag'RANGE);

begin

  ctag_address<=ctag(address_tag'HIGH downto address_tag'LOW);

  tagmem: generic_dp_ram
  generic map (
    address_bits  => CACHE_LINE_ID_BITS,
    data_bits     => ADDRESS_HIGH-CACHE_MAX_BITS+2
  )
  port map (
    clka      => wb_clk_i,
    ena       => tag_mem_enable,
    wea       => '0',
    addra     => cache_addr_read(CACHE_MAX_BITS-1 downto CACHE_LINE_SIZE_BITS),--line,
    dia       => dignore,--(others => DontCareValue),
    doa       => ctag,

    clkb      => wb_clk_i,
    enb       => '1',
    web       => r.tag_mem_wen,
    addrb     => tag_mem_addr,
    dib       => tag_mem_data,
    dob       => open
  );

  valid_i <= ctag(ctag'HIGH);

  process(r.state, line_save, tag_save, r.flushcnt, tagen, exttag_save)
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
      tag_mem_addr <= line_save;
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

  cachemem: generic_dp_ram
  generic map (
    address_bits => cache_addr_read'LENGTH,
    data_bits => 32
  )
  port map (
    clka      => wb_clk_i,
    ena       => tag_mem_enable,
    wea       => '0',
    addra     => cache_addr_read,
    dia       => dignore32,
    doa       => data,

    clkb      => wb_clk_i,
    enb       => '1',
    web       => m_wb_ack_i,
    addrb     => cache_addr_write,
    dib       => m_wb_dat_i,
    dob       => open
  );


  process(r,strobe,enable,miss,wb_rst_i,wb_clk_i,line,line_offset,line_save)
    variable ett: std_logic_vector(exttag_save'RANGE);
    variable w: icache_regs_type;
  begin

    w:=r;

    w.busy := '0';
    w.cyc := '0';
    w.stb := '0';
    w.tag_mem_wen := '0';
    w.fill_success :='0';
    w.flushcnt := (others => 'X');

    cache_addr_read <= line & line_offset;
    cache_addr_write <= line_save & std_logic_vector(r.offcnt_write(r.offcnt_write'HIGH downto 2));
    valid <= '0';
    tag_mem_enable <= enable and strobe;

    case r.state is

      when flushing =>
        w.busy := '1';
        w.flushcnt := r.flushcnt - 1;
        w.tag_mem_wen := '1';
        w.wbaddr(31 downto CACHE_MAX_BITS) := (others => 'X');

        stall <= '1';

        if r.flushcnt=0 then
          w.tag_mem_wen:='0';
          w.state := running;
        end if;

      when running =>

        w.offcnt := (others => 'X');
        w.offcnt_write := (others => 'X');
        w.wbaddr(31 downto CACHE_MAX_BITS) := (others => 'X');

        stall <= '0';

        w.access_q := '0';
        w.queued_address := '0';

        if strobe='1' and enable='1' then
          w.save_addr := address;
          w.access_q := '1';
        end if;

        valid <= hit;

        if r.access_q='1' then
          -- We had a cache access in last clock cycle.
          if enable='1' then
 
            if miss='1' then -- And it was a miss...
              -- Recover last address
              w.save_addr := r.save_addr;
              w.queued_address := '1';
              --
              stall <= '1';
              valid <= '0';

              w.wbaddr(31 downto CACHE_MAX_BITS) := r.save_addr(31 downto CACHE_MAX_BITS);
              w.state := filling;

              w.offcnt        := (others => '0');
              w.offcnt_write  := (others => '0');
 
              w.cyc   := '1';
              w.stb   := '1';
              w.busy  := '1';
            else
              valid <= '1';
            end if;
          end if;
        end if;

        if flush='1' then
          w.state := flushing;
          w.flushcnt := (others => '1');
          w.tag_mem_wen := '1';
        end if;

      when filling =>
        stall <= '1';
        w.busy:= '1';
        w.cyc := '1';
        w.stb := '1';

        cache_addr_read <= r.save_addr(CACHE_MAX_BITS-1 downto 2);
        tag_mem_enable <= '1';

        if m_wb_ack_i='1' then
          w.offcnt_write := r.offcnt_write + 1;
          -- This will go to 0, but we check before and switch state
          if r.offcnt_write=offcnt_full then
            w.tag_mem_wen := '1';
            w.state := waitwrite;
          end if;
        end if;
          
        if m_wb_stall_i='0' then
          if r.offcnt(r.offcnt'HIGH)='0' then
            w.offcnt := r.offcnt + 1;
          end if;
        end if;

      when waitwrite =>
        w.busy := '1';
        w.wbaddr(31 downto CACHE_MAX_BITS) := (others => 'X');
        w.offcnt := (others => 'X');
        w.offcnt_write := (others => 'X');
        tag_mem_enable <= '1';
        cache_addr_read <= r.save_addr(CACHE_MAX_BITS-1 downto 2);
        w.state := ending;
        stall <= '1';

      when ending =>
        w.busy :='0';
        w.wbaddr(31 downto CACHE_MAX_BITS) := (others => 'X');
        w.offcnt := (others => 'X');
        w.offcnt_write := (others => 'X');
        tag_mem_enable <= '1';
        cache_addr_read <= r.save_addr(CACHE_MAX_BITS-1 downto 2);
        stall <= '1';

        if enable='1' then
          w.fill_success := '1';
        end if;

        w.state := running;
    end case;

    if wb_rst_i='1' then
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
    end if;

    if rising_edge(wb_clk_i) then
      r <= w;
    end if;



  end process;

  loadsave<='1' when r.state=ending else '0';

  process(r.fill_success, r.busy, hit)
  begin
    if r.busy='1' then
      ack <= '0';
    elsif r.fill_success='1' then
      ack <= '1';
    else
      ack <= hit;
    end if;
  end process;

  access_i <= strobe;

  hit <= '1' when tag_match='1' and valid_i='1' else '0';

  miss <= not hit;

  process(wb_clk_i)
    variable requested_offset: unsigned(5 downto 2);
  begin
    if rising_edge(wb_clk_i) then
      valid_while_filling<='0';
      requested_offset := unsigned(cache_addr_read(5 downto 2));
      if r.state=filling and r.offcnt_write(5 downto 2) > requested_offset then
        valid_while_filling<='1';
      end if;
    end if;
  end process;

  m_wb_cyc_o  <= r.cyc;
  m_wb_stb_o  <= r.stb when r.offcnt(r.offcnt'HIGH)='0' else '0';
  m_wb_we_o   <= '0';
  m_wb_dat_o  <= (others => 'X');

  m_wb_adr_o(31 downto CACHE_MAX_BITS) <= r.wbaddr(31 downto CACHE_MAX_BITS);
  m_wb_adr_o(CACHE_MAX_BITS-1 downto CACHE_LINE_SIZE_BITS) <= r.save_addr(CACHE_MAX_BITS-1 downto CACHE_LINE_SIZE_BITS);
  m_wb_adr_o(CACHE_LINE_SIZE_BITS-1 downto 2) <= std_logic_vector(r.offcnt(CACHE_LINE_SIZE_BITS-1 downto 2));

  m_wb_adr_o(1 downto 0) <= "00";

end behave;
