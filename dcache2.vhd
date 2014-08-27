library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;

use ieee.numeric_std.all;

library work;
use work.xtcpkg.all;
use work.xtccomppkg.all;
use work.wishbonepkg.all;
-- synopsys translate_off
use work.txt_util.all;
-- synopsys translate_on


entity dcache is
  generic (
      ADDRESS_HIGH: integer := 31;
      CACHE_MAX_BITS: integer := 11; -- 8 Kb
      CACHE_LINE_SIZE_BITS: integer := 6 -- 64 bytes
  );
  port (
    syscon:     in wb_syscon_type;
    ci:         in dcache_in_type;
    co:         out dcache_out_type;
    mwbi:       in wb_miso_type;
    mwbo:       out wb_mosi_type
  );
end dcache;

architecture behave of dcache is
  
  constant CACHE_LINE_ID_BITS: integer := CACHE_MAX_BITS-CACHE_LINE_SIZE_BITS;

  subtype address_type is std_logic_vector(ADDRESS_HIGH downto 2);
  -- A line descriptor
  subtype line_number_type is std_logic_vector(CACHE_LINE_ID_BITS-1 downto 0);
  -- Offset within a line
  subtype line_offset_type is std_logic_vector(CACHE_LINE_SIZE_BITS-1-2 downto 0);
  -- A tag descriptor
  subtype tag_type is std_logic_vector((ADDRESS_HIGH-CACHE_MAX_BITS) downto 0);
  -- A full tag memory descriptor. Includes valid bit and dirty bit
  subtype full_tag_type is std_logic_vector(ADDRESS_HIGH-CACHE_MAX_BITS+2 downto 0);

  constant VALIDBIT: integer := ADDRESS_HIGH-CACHE_MAX_BITS+1;
  constant DIRTYBIT: integer := ADDRESS_HIGH-CACHE_MAX_BITS+2;
  ------------------------------------------------------------------------------

  type state_type is (
    idle,
    readline,
    writeback,
    recover,
    write_after_fill,
    settle,
    flush,
    directmemory
  );

  constant BURSTWORDS: integer :=  (2**(CACHE_LINE_SIZE_BITS-2))-1;

  type regs_type is record
    req:            std_logic;
    req_addr:       address_type;
    req_we:         std_logic;
    req_wmask:      std_logic_vector(3 downto 0);
    req_data:       std_logic_vector(31 downto 0);
    req_tag:        std_logic_vector(31 downto 0);
    req_accesstype: std_logic_vector(1 downto 0);
    fill_offset_r:    line_offset_type;
    req_offset:       line_offset_type;
    fill_offset_w:    line_offset_type;
    finished_w:       line_offset_type;
    fill_tag:         tag_type;
    fill_line_number: line_number_type;
    flush_line_number: line_number_type;
    fill_r_done:      std_logic;
    ack_write:        std_logic;
    writeback_tag:    tag_type;
    state:            state_type;
    misses:           integer;
    rvalid:           std_logic;
    wr_conflict:      std_logic;
    ack_q:            std_logic;
    ack_q_q:            std_logic;
    flush_req:        std_logic;
    in_flush:         std_logic;
    count:            integer;-- range 0 to BURSTWORDS;
  end record;

  function address_to_tag(a: in address_type) return tag_type is
    variable t: tag_type;
  begin
    t:= a(ADDRESS_HIGH downto CACHE_MAX_BITS);
    return t;
  end address_to_tag;

  function address_to_line_number(a: in address_type) return line_number_type is
    variable r: line_number_type;
  begin
    r:=a(CACHE_MAX_BITS-1 downto CACHE_LINE_SIZE_BITS);
    return r;
  end address_to_line_number;

  function address_to_line_offset(a: in address_type) return line_offset_type is
    variable r: line_offset_type;
  begin
    r:=a(CACHE_LINE_SIZE_BITS-1 downto 2);
    return r;
  end address_to_line_offset;

  ------------------------------------------------------------------------------

  component reqcnt is
  port (
    clk:  in std_logic;
    rst:  in std_logic;

    stb:  in std_logic;
    cyc:  in std_logic;
    stall:in std_logic;
    ack:  in std_logic;

    req:  out std_logic;
    lastreq:  out std_logic;
    count:  out unsigned(2 downto 0)
  );
  end component;



  -- extracted values from port A
  signal line_number:   line_number_type;

  -- Some helpers
  signal hit: std_logic;
  --signal miss: std_logic;
  --attribute keep : string;
 -- attribute keep of a_miss : signal is "true";
  --attribute keep of b_miss : signal is "true";
  --signal a_b_conflict: std_logic;
  
  -- Connection to tag memory

  signal tmem_ena:    std_logic;
  signal tmem_wea:    std_logic;
  signal tmem_addra:  line_number_type;
  signal tmem_dia:    full_tag_type;
  signal tmem_doa:    full_tag_type;
  signal tmem_enb:    std_logic;
  signal tmem_web:    std_logic;
  signal tmem_addrb:  line_number_type;
  signal tmem_dib:    full_tag_type;
  signal tmem_dob:    full_tag_type;

  signal cmem_ena:    std_logic;
  signal cmem_wea:    std_logic_vector(3 downto 0);
  signal cmem_dia:    std_logic_vector(31 downto 0);
  signal cmem_doa:    std_logic_vector(31 downto 0);
  signal cmem_addra:  std_logic_vector(CACHE_MAX_BITS-1 downto 2);

  signal cmem_enb:    std_logic;
  signal cmem_web:    std_logic_vector(3 downto 0);
  signal cmem_dib:    std_logic_vector(31 downto 0);
  signal cmem_dob:    std_logic_vector(31 downto 0);
  signal cmem_addrb:  std_logic_vector(CACHE_MAX_BITS-1 downto 2);

  signal r: regs_type;
  signal same_address: std_logic;

  constant offset_all_ones: line_offset_type := (others => '1');
  constant offset_all_zeroes: line_offset_type := (others => '0');
  constant line_number_all_ones: line_number_type := (others => '1');

  signal dbg_valid: std_logic;
  signal dbg_dirty: std_logic;
  signal dbg_miss: std_logic;
  signal req_in_progess: std_logic;
  signal req_last: std_logic;
  signal wb_stb, wb_cyc: std_logic;

begin

  -- These are alias, but written as signals so we can inspect them

  line_number <= address_to_line_number(ci.address(address_type'RANGE));

  -- TAG memory

  tagmem: generic_dp_ram_rf
  generic map (
    address_bits  => CACHE_LINE_ID_BITS,
    data_bits     => ADDRESS_HIGH-CACHE_MAX_BITS+3
  )
  port map (
    clka      => syscon.clk,
    ena       => tmem_ena,
    wea       => tmem_wea,
    addra     => tmem_addra,
    dia       => tmem_dia,
    doa       => tmem_doa,

    clkb      => syscon.clk,
    enb       => tmem_enb,
    web       => tmem_web,
    addrb     => tmem_addrb,
    dib       => tmem_dib,
    dob       => tmem_dob
  );

  -- Cache memory
  memgen: for i in 0 to 3 generate

  cachemem: generic_dp_ram_rf
  generic map (
    address_bits => cmem_addra'LENGTH,
    data_bits => 8
  )
  port map (
    clka      => syscon.clk,
    ena       => cmem_ena,
    wea       => cmem_wea(i),
    addra     => cmem_addra,
    dia       => cmem_dia(((i+1)*8)-1 downto i*8),
    doa       => cmem_doa(((i+1)*8)-1 downto i*8),

    clkb      => syscon.clk,
    enb       => cmem_enb,
    web       => cmem_web(i),
    addrb     => cmem_addrb,
    dib       => cmem_dib(((i+1)*8)-1 downto i*8),
    dob       => cmem_dob(((i+1)*8)-1 downto i*8)
  );

  end generate;


  co.in_flush <= r.in_flush;

  reqcnt_inst: reqcnt
  port map (
    clk   => syscon.clk,
    rst   => syscon.rst,
    stb   => wb_stb,
    cyc   => wb_cyc,
    stall => mwbi.stall,
    ack   => mwbi.ack,

    req   => req_in_progess,
    lastreq => req_last,
    count => open
  );

  mwbo.cyc<=wb_cyc;
  mwbo.stb<=wb_stb;



  process(r,syscon.clk,syscon.rst, ci, mwbi, tmem_doa,
          tmem_doa, tmem_dob, line_number, cmem_doa, cmem_dob,req_last)
    variable w: regs_type;
    variable have_request: std_logic;
    variable will_busy: std_logic;
    variable valid: std_logic;
    variable stall: std_logic;
    variable miss: std_logic;

  begin
    w := r;
    valid :='0';
    stall:='0';
    miss := DontCareValue;
    will_busy := '0';
    co.valid<='0';
    co.stall<='0';
    wb_cyc <= '0';
    wb_stb <= DontCareValue;
    mwbo.adr <= (others => DontCareValue);
    mwbo.dat <= (others => DontCareValue);
    mwbo.tag <= (others => DontCareValue);
    mwbo.we <= DontCareValue;
    mwbo.sel<=(others => '1');

    tmem_addra <= line_number;
    tmem_addrb <= address_to_line_number( r.req_addr );--(others => DontCareValue);
    tmem_ena <= '1';
    tmem_wea <= '0';
    tmem_enb <= '0';
    --tmem_web <= '0';
    --tmem_dib(tag_type'RANGE) <= address_to_tag(ci.address(r.req_addr'RANGE));--(others => DontCareValue);
    tmem_dib(tag_type'RANGE) <= address_to_tag(r.req_addr);--(others => DontCareValue);
    tmem_dib(DIRTYBIT)<=DontCareValue;
    tmem_dib(VALIDBIT)<=DontCareValue;

    tmem_dia <= (others => DontCareValue);

    -- content memory is accessed at same time as tag memory

    cmem_addra <= ci.address(CACHE_MAX_BITS-1 downto 2);
    cmem_addrb <= r.req_addr(CACHE_MAX_BITS-1 downto 2);
    cmem_ena <= ci.enable and ci.strobe;


    if ci.we='0' then
      cmem_wea <= "0000";
    else
      if ci.accesstype/=ACCESS_NOCACHE then
        cmem_wea <= ci.wmask;
      else
        cmem_wea <= "0000";
      end if;
    end if;

    cmem_web <= "0000";
    cmem_dia <= ci.data;

    cmem_enb <= r.req;-- and not miss; --ci.b_enable;

    --cmem_dia <= (others => DontCareValue); -- No writes on port A
    cmem_dib <= r.req_data;--ci.b_data_in;--(others => DontCareValue);

    co.data <= cmem_doa;
    --co.b_data_out <= cmem_dob;

    --w.ack_b_write := '0';
    w.rvalid := 'X';
    -- synopsys translate_off
    dbg_valid <= tmem_doa(VALIDBIT);
    dbg_dirty <= tmem_doa(DIRTYBIT);
    -- synopsys translate_on

    tmem_web <= '0';
    co.tag <= r.req_tag;

    w.ack_q_q := '0';
    w.ack_q := '0';

    case r.state is

      when idle =>
        co.stall<='0';
        -- Now, after reading from tag memory....
        if (r.req='1') then
          -- We had a request, check
          miss:='1';
          if tmem_doa(VALIDBIT)='1' then
            if tmem_doa(tag_type'RANGE) = address_to_tag(r.req_addr) then
              miss:='0';
            end if;
          end if;
          -- For noncache access, we mark it as
          -- miss.
          if r.req_accesstype=ACCESS_NOCACHE then
            miss := '1';
          end if;

          co.valid<=not miss;
        else
          co.valid<='0';
          miss:='0';
        end if;

        -- Miss handling
        if miss='1' then
         if r.req_accesstype/=ACCESS_NOCACHE then
          co.stall <= '1';
          valid := '0';
          w.misses := r.misses+1;

          w.fill_tag := address_to_tag(r.req_addr);
          w.fill_line_number := address_to_line_number(r.req_addr);
          w.count := BURSTWORDS;
          w.fill_r_done := '0';
          w.fill_offset_r := r.req_offset;
          w.fill_offset_w := r.req_offset;
 
          if tmem_doa(VALIDBIT)='1' then
            if tmem_doa(DIRTYBIT)='1' then
              -- Read/Write miss to a dirty line for a different
              -- tag.
              w.writeback_tag := tmem_doa(tag_type'RANGE);
              if r.req_we='1' then
                --- Oops, we wrote to the wrong line.
                w.state := recover; -- was writeback
              else
                -- TODO: if this is a direct access, no need to writeback.
                w.rvalid := '0';
                --w.fill_r_done := '0';

                w.fill_offset_r := (others => '0');
                w.fill_offset_w := (others => '0');
                w.state := writeback;
              end if;
              will_busy :='1';

            else
              -- Read/Write to a non-dirty line for a different
              -- tag.
              w.state := readline;
              will_busy :='1';
            end if;
          else
            -- Read/Write to a non-present line for a different
            -- tag.
            if r.req_we='1' then
              -- It's a write.
              case r.req_accesstype is
                when ACCESS_WB_WA =>
                  w.state := readline;
                when ACCESS_WB_NA | ACCESS_WT =>
                  -- Non-cacheable access, no allocate or writethrough.
                  -- Need to perform write directly to memory
                  w.state := directmemory;
                  w.fill_r_done := '0';
                when others =>
                  --
              end case;

            else
              -- It's a read.

              w.state := readline;

            end if;
            will_busy :='1';
          end if;
         else
          -- Non-cacheable address.
          w.state := directmemory;
          w.fill_r_done := '0';
          will_busy := '1';
          co.stall<='1';
         end if;
        else
          -- This is a hit. Make sure we write the dirty bit (for writes).
          tmem_web<=r.req_we;
          tmem_enb<=r.req;
          tmem_dib(DIRTYBIT)<='1';
          tmem_dib(VALIDBIT)<='1';

          valid := '1';
        end if;

        if r.flush_req='1' then
          will_busy :='1';
          co.stall <= '1';

          cmem_enb <= '0';
          cmem_dib <= (others => DontCareValue);
          cmem_addrb <= (others => DontCareValue);
          w.state := flush;
          w.fill_line_number := (others => '0');
          w.flush_line_number := (others => '0');
        end if;

        have_request := '0';

        -- Queue requests
        if will_busy='0' then
          w.req := ci.strobe and ci.enable;
          w.req_we := ci.we;
          w.req_wmask := ci.wmask;
          w.req_data := ci.data;
          w.req_tag := ci.tag;
          w.req_accesstype := ci.accesstype;
          co.stall<='0';
          if ci.strobe='1' and ci.enable='1' then
            have_request := '1';
            w.req_addr(address_type'RANGE) := ci.address(address_type'RANGE);
            w.req_offset := address_to_line_offset(ci.address(address_type'RANGE));
          end if;
        end if;

      when directmemory =>
        co.stall <= '1';
        tmem_web <= '0';

        mwbo.adr <=(others => '0');
        mwbo.adr (ADDRESS_HIGH downto 2) <= r.req_addr;
        wb_cyc <='1';
        wb_stb <=not r.fill_r_done;
        mwbo.we <= r.req_we;
        mwbo.sel <= r.req_wmask;
        mwbo.dat <= r.req_data;
        mwbo.tag <= r.req_tag;

        co.data <= mwbi.dat;
        co.tag <= mwbi.tag;

        if mwbi.stall='0' then
          w.fill_r_done:='1';
        end if;
        if mwbi.ack='1' then
          co.valid<='1';
          co.stall<='0';

          w.req := ci.strobe and ci.enable;
          w.req_we := ci.we;
          w.req_wmask := ci.wmask;
          w.req_data := ci.data;
          w.req_tag := ci.tag;
          w.req_accesstype := ci.accesstype;
          co.stall<='0';
          if ci.strobe='1' and ci.enable='1' then
            have_request := '1';
            w.req_addr(address_type'RANGE) := ci.address(address_type'RANGE);
            w.req_offset := address_to_line_offset(ci.address(address_type'RANGE));

          end if;

          w.state:=idle;
        end if;

      when readline =>
        co.stall <= '1';
        tmem_web <= '0';

        w.ack_q := mwbi.ack;
        w.ack_q_q := r.ack_q;

        mwbo.adr<=(others => '0');
        mwbo.adr(ADDRESS_HIGH downto 2) <= r.fill_tag & r.fill_line_number & r.fill_offset_r;
        mwbo.tag(cmem_addrb'LENGTH-1 downto 0) <= r.fill_line_number & r.fill_offset_r;
        mwbo.tag(cmem_addrb'LENGTH) <= '1';

        wb_cyc<='1';
        wb_stb<=not r.fill_r_done;
        mwbo.we<='0';

        cmem_addrb <= mwbi.tag(cmem_addrb'LENGTH-1 downto 0);--r.fill_line_number & r.fill_offset_w;
        cmem_addra <= r.req_addr(CACHE_MAX_BITS-1 downto 2);--r.req_offset;--(others => DontCareValue);
        cmem_enb <= '1';
        cmem_ena <= '1';
        cmem_wea <= (others => '0');
        cmem_dia <= (others => 'X');
        cmem_web <= (others => mwbi.ack);
        cmem_dib <= mwbi.dat;

        if mwbi.stall='0' and r.fill_r_done='0' then
          if w.count=0 then--r.fill_offset_r = offset_all_ones then
            w.fill_r_done := '1';
          else
            w.fill_offset_r := std_logic_vector(unsigned(r.fill_offset_r) + 1);
            w.count := w.count - 1;
          end if;
        end if;

        --if r.ack_q='1' then
        --end if;

        if mwbi.ack='1' then
          w.fill_offset_w := std_logic_vector(unsigned(r.fill_offset_w) + 1);
          w.finished_w := r.fill_offset_w;
          --if r.fill_offset_w=offset_all_ones then
          if r.fill_r_done='1' and req_last='1' then
            w.state := settle;
            tmem_addrb <= r.fill_line_number;
            tmem_dib(tag_type'RANGE) <= r.fill_tag;
            tmem_dib(VALIDBIT)<='1';
            tmem_dib(DIRTYBIT)<=r.req_we;
            tmem_web<='1';
            tmem_enb<='1';
            tmem_ena<='0';
            if r.req_we='1' then
              -- Perform write
              w.state := write_after_fill;
            end if;
          end if;
        else
          cmem_dia <= (others => DontCareValue);
          cmem_dib <= (others => DontCareValue);
        end if;

        -- Validate read for IWF
        if r.ack_q_q='1' then
          if r.finished_w=r.req_offset then
            co.valid<='1';
            co.tag<=r.req_tag;
            w.req :='0';
          end if;
        end if;


      when recover =>
        -- Recover lost data on the content memory
        co.stall <= '1';
        cmem_addrb <= r.req_addr(CACHE_MAX_BITS-1 downto 2);
        cmem_enb <= '1';
        cmem_web <= "1111";
        cmem_dib <= cmem_doa;

        -- synthesis translate_off
        report "Recover write";
        -- synthesis translate_on

        w.rvalid := '0';
        w.fill_r_done := '0';
        w.state := writeback;

      when writeback =>

        co.stall <= '1';
        w.rvalid := '1';

        mwbo.adr<=(others => '0');
        mwbo.adr(ADDRESS_HIGH downto 2) <= r.writeback_tag & r.fill_line_number & r.fill_offset_w;
        wb_cyc<=r.rvalid ; --'1';
        wb_stb<=r.rvalid and not r.fill_r_done;--not r.fill_r_done;
        mwbo.we<=r.rvalid; --1';
        mwbo.sel<= (others => '1');

        if mwbi.stall='0' then
          w.fill_offset_r := std_logic_vector(unsigned(r.fill_offset_r) + 1);
          w.fill_offset_w := r.fill_offset_r;
        end if;

        if mwbi.stall='0' and r.rvalid='1' and r.fill_r_done='0' then
          if r.fill_offset_r = offset_all_ones then
            w.fill_r_done := '1';
          end if;
        end if;

        --if (mwbi.stall='0' or r.rvalid='0') and r.fill_r_done='0' then
        if (mwbi.ack='1') then
          --w.fill_offset_w := std_logic_vector(unsigned(r.fill_offset_w) + 1);
          --if r.fill_offset_w=offset_all_ones then
          if req_last='1' then
            --w.fill_offset_r := (others => '0');
            --w.fill_offset_w := (others => '0');
            --w.fill_r_done := '1';
            if r.in_flush='1' then
              w.state := flush;
              w.in_flush:='0';
            else
              w.fill_offset_r := r.req_offset;--(others => '0');
              w.fill_offset_w := r.req_offset;--(others => '0');
              w.fill_r_done := '0';
              w.state := readline;
            end if;
            --report "End writeback";
            --w.state := readline;
          end if;
        end if;

        --if r.fill_is_b='1' then
          mwbo.dat <= cmem_dob;

          cmem_addrb <= (r.fill_line_number & r.fill_offset_r) ;
          cmem_enb <= not mwbi.stall or not r.rvalid;
          --cmem_ena <= '0';
          cmem_addra <= (others => DontCareValue);
          cmem_web <= (others=>'0');

        --else
        --  mwbo.dat <= cmem_doa;
        --  cmem_addra <= r.fill_line_number & r.fill_offset_w;
        --  cmem_ena <= not mwbi.stall or not r.rvalid;
        --  cmem_enb <= '0';
        --  cmem_addrb <= (others => DontCareValue);
        --  cmem_wea <= (others=>'0');
        --end if;






      when write_after_fill =>

        cmem_addra <= (others => DontCareValue);
        cmem_addrb <= r.req_addr(CACHE_MAX_BITS-1 downto 2);
        cmem_dib <= r.req_data;
        cmem_web <= r.req_wmask;
        cmem_enb <= '1';
        cmem_ena <= '0';
        cmem_dia <= (others => 'X');
        cmem_wea <= (others => 'X');

        co.stall <= '1';
        --b_stall := '1';
        valid := '0'; -- ERROR
        --b_valid := '0'; -- ERROR
        --w.ack_b_write := '1';
        w.state := settle;

      when settle =>
        cmem_addra <= r.req_addr(CACHE_MAX_BITS-1 downto 2);--r.fill_tag & r.fill_line_number & r.fill_offset_w;
        cmem_addrb <= r.req_addr(CACHE_MAX_BITS-1 downto 2);--r.fill_tag & r.fill_line_number & r.fill_offset_w;
        cmem_web <= (others => '0');
        cmem_wea <= (others => '0');
        tmem_ena <= '1';
        cmem_ena <= '1';
        tmem_addra <= address_to_line_number(r.req_addr);
        tmem_addrb <= address_to_line_number(r.req_addr);
        co.stall <= '1';
        --b_stall := '1';
        tmem_web <= '0';

        valid := '0'; -- ERROR
        --b_valid := '0';--r.ack_b_write; -- ERROR -- note: don't ack writes
        w.state := idle;

      when flush =>

        stall:='1';
        valid:='0';

        tmem_addrb <= r.flush_line_number;
        tmem_addra <= (others => DontCareValue);
        tmem_ena <='0';
        tmem_wea <='0';

        tmem_dib(VALIDBIT)<='0';
        tmem_dib(DIRTYBIT)<='0';

        tmem_web<='1';
        tmem_enb<='1';
        cmem_enb <= '0';
        cmem_addra <= (others => DontCareValue);
        cmem_addrb <= (others => DontCareValue);
        cmem_dia <= (others => DontCareValue);
        cmem_dib <= (others => DontCareValue);
        
        w.flush_line_number := r.flush_line_number+1;

        w.fill_offset_r := (others => '0');
        w.in_flush := '1';
        w.flush_req := '0';

        -- only valid in next cycle
        if r.in_flush='1' and tmem_dob(VALIDBIT)='1' and tmem_dob(DIRTYBIT)='1' then
          report "Need to wb" severity note;
          w.writeback_tag := tmem_dob(tag_type'RANGE);   -- NOTE: can we use tmem_doa ?
          --w.fill_is_b := '1';
          tmem_web<='0';
          w.fill_offset_r := (others => '0');
          w.flush_line_number := r.flush_line_number;
          w.fill_r_done := '0';
          w.rvalid := '1';
          w.state := writeback;
        else
          w.fill_line_number := r.flush_line_number;

          if r.fill_line_number = line_number_all_ones then --r.in_flush='1' and r.fill_line_number=line_number_all_zeroes then
            w.state := idle;
            w.in_flush :='0';
          end if;
        end if;

    end case;

    if ci.flush='1' then
      w.flush_req :='1';
    end if;

    if syscon.rst='1' then

        w.req := '0';
        w.misses :=0;
        w.flush_req :='1';
        w.in_flush :='0';
        w.req:='0';
        w.req_we:='0';
        --r.fill_line_number := (others => '0');
       -- r.flush_line_number := (others => '0');
        --r.state <= flush;
        w.state := idle;
        --co.valid <= '0';
    end if;

    if rising_edge(syscon.clk) then
        --co.valid <= valid;
        --co.b_valid <= b_valid;
        --co.a_stall <= a_stall;
        --co.b_stall <= b_stall;
        r <= w;
    end if;
    dbg_miss<=miss;
  end process;

end behave;
