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

  signal save_addr: std_logic_vector(address'RANGE);


  alias line: std_logic_vector(CACHE_LINE_ID_BITS-1 downto 0)
    is address(CACHE_MAX_BITS-1 downto CACHE_LINE_SIZE_BITS);

  alias line_offset: std_logic_vector(CACHE_LINE_SIZE_BITS-1 downto 2)
    is address(CACHE_LINE_SIZE_BITS-1 downto 2);

  alias address_tag: std_logic_vector(ADDRESS_HIGH-CACHE_MAX_BITS downto 0)
    is save_addr(ADDRESS_HIGH downto CACHE_MAX_BITS);

  signal ctag: std_logic_vector(ADDRESS_HIGH-CACHE_MAX_BITS+1 downto 0);

  type validmemtype is ARRAY(0 to (2**line'LENGTH)-1) of std_logic;
  shared variable valid_mem: validmemtype;

  signal tag_mem_wen: std_logic;
  signal miss: std_logic;
  signal ack: std_logic;
  signal offcnt: unsigned(line_offset'HIGH+1 downto 2);
  signal offcnt_write: unsigned(line_offset'HIGH downto 2);

  constant offcnt_full: unsigned(line_offset'HIGH downto 2) := (others => '1');

  signal tag_match: std_logic;
  signal cyc, stb: std_logic;
  signal cache_addr_read,cache_addr_write:
    std_logic_vector(CACHE_MAX_BITS-1 downto 2);

  alias tag_save: std_logic_vector(ADDRESS_HIGH-CACHE_MAX_BITS downto 0)
    is save_addr(ADDRESS_HIGH downto CACHE_MAX_BITS);

  alias line_save: std_logic_vector(CACHE_LINE_ID_BITS-1 downto 0)
    is save_addr(CACHE_MAX_BITS-1 downto CACHE_LINE_SIZE_BITS);

  signal access_i: std_logic;
  signal access_q: std_logic;
  signal stall_i, valid_i: std_logic;
  signal busy: std_logic;
  signal hit: std_logic;
  signal tag_mem_enable: std_logic;
  signal exttag_save: std_logic_vector(ADDRESS_HIGH-CACHE_MAX_BITS downto 0);

  type state_type is (
    flushing,
    running,
    filling,
    waitwrite,
    ending
  );

  signal state: state_type;
  signal fill_success: std_logic;

  signal tag_mem_data: std_logic_vector(ADDRESS_HIGH-CACHE_MAX_BITS+1 downto 0);
  signal tag_mem_addr: std_logic_vector(CACHE_LINE_ID_BITS-1 downto 0);

  signal tag_mem_ena: std_logic;

  signal flushcnt: unsigned(line'RANGE);

  --constant line_length: integer := CACHE_LINE_ID_BITS;
  --constant ctag_length: integer := ADDRESS_HIGH-CACHE_MAX_BITS;
  constant dignore: std_logic_vector(ctag'RANGE) := (others => DontCareValue);

  constant dignore32: std_logic_vector(31 downto 0) := (others => DontCareValue);

  signal ctag_address: std_logic_vector(address_tag'RANGE);
  signal loadsave: std_logic;
begin

  ctag_address<=ctag(address_tag'HIGH downto address_tag'LOW);
  m_wb_we_o <= '0';
  m_wb_dat_o <= (others => 'X');

  tagmem: generic_dp_ram
  generic map (
    address_bits  => CACHE_LINE_ID_BITS,
    data_bits     => ADDRESS_HIGH-CACHE_MAX_BITS+2
  )
  port map (
    clka      => wb_clk_i,
    ena       => tag_mem_enable,
    wea       => '0',
    addra     => address(CACHE_MAX_BITS-1 downto CACHE_LINE_SIZE_BITS),--line,
    dia       => dignore,--(others => DontCareValue),
    doa       => ctag,

    clkb      => wb_clk_i,
    enb       => '1',
    web       => tag_mem_wen,
    addrb     => tag_mem_addr,
    dib       => tag_mem_data,
    dob       => open
  );

  valid_i <= ctag(ctag'HIGH);

  process(state, line_save, tag_save, flushcnt, tagen, exttag_save)
    variable wrtag: std_logic_vector(ADDRESS_HIGH-CACHE_MAX_BITS downto 0);

  begin
    if tagen='1' then
    wrtag := exttag_save;
    else
    wrtag := tag_save;
    end if;
    if state=flushing then
      tag_mem_data <= '0' & wrtag;
      tag_mem_addr <= std_logic_vector(flushcnt);
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

  stall <= stall_i;
  valid <= ack;
  tag_mem_enable <= access_i;-- and enable;
  m_wb_dat_o(31 downto 0) <= (others => DontCareValue);

  -- Address save
  process(wb_clk_i)
  begin
    if rising_edge(wb_clk_i) then
      if (stall_i='0' and enable='1' and strobe='1') or (loadsave='1'and enable='1' and strobe='1') then
        save_addr <= address;
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
    ena       => tag_mem_ena,               -- enable and strobe ?
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

  tag_mem_ena <= enable and strobe;

  process(wb_clk_i)
  begin
    if rising_edge(wb_clk_i) then
      if wb_rst_i='1' then
        access_q<='0';
      else
        if busy='0' and enable='1' then
          access_q <= access_i;
        elsif abort='1' then
          access_q<='0';
        end if;
      end if;
    end if;
  end process;


  process(wb_clk_i)
    variable ett: std_logic_vector(exttag_save'RANGE);
  begin
    if rising_edge(wb_clk_i) then
      if wb_rst_i='1' then
        state <= flushing;
        busy <= '1';
        fill_success <='0';
        --offcnt <= (others => '0');
        flushcnt <= (others => '1');
        tag_mem_wen <= '1'; -- this needed ??
        cyc <= '0';
        stb <= '0';
        m_wb_adr_o(31 downto CACHE_MAX_BITS) <= (others => 'X');
        offcnt <= (others => 'X');
        offcnt_write <= (others => 'X');

      else
        busy <= '0';
        cyc <= '0';
        stb <= '0';
        tag_mem_wen <= '0';
        fill_success <='0';
        flushcnt <= (others => 'X');

        case state is

          when flushing =>
            busy <= '1';
            flushcnt <= flushcnt - 1;
            tag_mem_wen<='1';
            m_wb_adr_o(31 downto CACHE_MAX_BITS) <= (others => 'X');
            if flushcnt=0 then
              tag_mem_wen<='0';
              state <= running;
            end if;

          when running =>
            offcnt <= (others => 'X');
            offcnt_write <= (others => 'X');
            m_wb_adr_o(31 downto CACHE_MAX_BITS) <= (others => 'X');

            if flush='1' then
              state <= flushing;
              flushcnt <= (others => '1');
              tag_mem_wen <= '1';
            else

              if access_q='1' and abort='0' then
                if miss='1' and enable='1' then
                  ett:=        tag(ADDRESS_HIGH downto CACHE_MAX_BITS);
  
                  exttag_save <= ett;--tag(ADDRESS_HIGH downto CACHE_MAX_BITS);
                  -- synthesis translate_off
                  --report str(ADDRESS_HIGH) & " " & hstr(ett);
                  -- synthesis translate_on
                  state <= filling;
  
                  if tagen='1' then
                    m_wb_adr_o(31 downto CACHE_MAX_BITS) <= ett;
                  else
                    m_wb_adr_o(31 downto CACHE_MAX_BITS) <= save_addr(31 downto CACHE_MAX_BITS);
                  end if;

                  offcnt <= (others => '0');
                  offcnt_write <= (others => '0');
  
                  cyc <= '1';
                  stb <= '1';
                  busy <= '1';

                end if;
              end if;
            end if;
          when filling =>
            busy<='1';
            cyc <= '1';
            stb <= '1';

            if m_wb_ack_i='1' then
              offcnt_write <= offcnt_write + 1;
              -- This will go to 0, but we check before and switch state
              if offcnt_write=offcnt_full then
                tag_mem_wen<='1';
                state <= waitwrite;
              end if;
            end if;
              
            if m_wb_stall_i='0' then
              if offcnt(offcnt'HIGH)='0' then
                offcnt <= offcnt + 1;
              end if;
            end if;

          when waitwrite =>
            busy<='1';
            m_wb_adr_o(31 downto CACHE_MAX_BITS) <= (others => 'X');
            offcnt <= (others => 'X');
            offcnt_write <= (others => 'X');

            state <= ending;

          when ending =>
            busy<='0';
            m_wb_adr_o(31 downto CACHE_MAX_BITS) <= (others => 'X');
            offcnt <= (others => 'X');
            offcnt_write <= (others => 'X');

            if enable='1' then
              fill_success<='1';
            end if;

            state <= running;
        end case;
      end if;
    end if;
  end process;

  loadsave<='1' when state=ending else '0';

  process(fill_success, busy, hit)
  begin
    if busy='1' then
      ack <= '0';
    elsif fill_success='1' then
      ack <= '1';
    else
      ack <= hit;
    end if;
  end process;

  access_i <= strobe;

  hit <= '1' when tag_match='1' and valid_i='1' else '0';

  miss <= not hit;

  cache_addr_read <= line & line_offset when stall_i='0' else save_addr(CACHE_MAX_BITS-1 downto 2);

  cache_addr_write <= line_save & std_logic_vector(offcnt_write(offcnt_write'HIGH downto 2));

  process(busy,miss,access_q,fill_success)
  begin
    if busy='1' then
      stall_i<='1';
    elsif fill_success='1' then
      stall_i <= '0';
    else
      if access_q='1' then
        stall_i<=miss;
      else
        stall_i<='0';
      end if;
    end if;
  end process;

  m_wb_cyc_o  <= cyc;
  m_wb_stb_o  <= stb when offcnt(offcnt'HIGH)='0' else '0';
  m_wb_we_o   <= '0';
  m_wb_adr_o(CACHE_MAX_BITS-1 downto CACHE_LINE_SIZE_BITS) <= save_addr(CACHE_MAX_BITS-1 downto CACHE_LINE_SIZE_BITS);
  m_wb_adr_o(CACHE_LINE_SIZE_BITS-1 downto 2) <= std_logic_vector(offcnt(CACHE_LINE_SIZE_BITS-1 downto 2));
  m_wb_adr_o(1 downto 0) <= "00";

end behave;
