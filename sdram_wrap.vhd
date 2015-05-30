library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library work;
use work.wishbonepkg.all;
use work.xtcpkg.all;

entity sdram_ctrl is
  generic (
    HIGH_BIT: integer := 24
  );
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;

    wb_dat_o: out std_logic_vector(31 downto 0);
    wb_dat_i: in std_logic_vector(31 downto 0);
    wb_adr_i: in std_logic_vector(31 downto 0);
    wb_tag_i: in std_logic_vector(31 downto 0);
    wb_tag_o: out std_logic_vector(31 downto 0);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_sel_i: in std_logic_vector(3 downto 0);
    wb_ack_o: out std_logic;
    wb_stall_o: out std_logic;
    dbg: out memory_debug_type;
    -- extra clocking
    clk_off_3ns: in std_logic;

    -- SDRAM signals
     DRAM_ADDR   : OUT   STD_LOGIC_VECTOR (11 downto 0);
     DRAM_BA      : OUT   STD_LOGIC_VECTOR (1 downto 0);
     DRAM_CAS_N   : OUT   STD_LOGIC;
     DRAM_CKE      : OUT   STD_LOGIC;
     DRAM_CLK      : OUT   STD_LOGIC;
     DRAM_CS_N   : OUT   STD_LOGIC;
     DRAM_DQ      : INOUT STD_LOGIC_VECTOR(15 downto 0);
     DRAM_DQM      : OUT   STD_LOGIC_VECTOR(1 downto 0);
     DRAM_RAS_N   : OUT   STD_LOGIC;
     DRAM_WE_N    : OUT   STD_LOGIC
  
  );

end entity sdram_ctrl;

architecture behave of sdram_ctrl is

  component sdram_controller is
  generic (
    HIGH_BIT: integer := 24;
    MHZ: integer := 96;
    REFRESH_CYCLES: integer := 4096;
    ADDRESS_BITS: integer := 13
  );
   PORT (
      clock_100:  in std_logic;
      clock_100_delayed_3ns: in std_logic;
      rst: in std_logic;

   -- Signals to/from the SDRAM chip
   DRAM_ADDR   : OUT   STD_LOGIC_VECTOR (ADDRESS_BITS-1 downto 0);
   DRAM_BA      : OUT   STD_LOGIC_VECTOR (1 downto 0);
   DRAM_CAS_N   : OUT   STD_LOGIC;
   DRAM_CKE      : OUT   STD_LOGIC;
   DRAM_CLK      : OUT   STD_LOGIC;
   DRAM_CS_N   : OUT   STD_LOGIC;
   DRAM_DQ      : INOUT STD_LOGIC_VECTOR(15 downto 0);
   DRAM_DQM      : OUT   STD_LOGIC_VECTOR(1 downto 0);
   DRAM_RAS_N   : OUT   STD_LOGIC;
   DRAM_WE_N    : OUT   STD_LOGIC;
   pending:  out std_logic;
   --- Inputs from rest of the system
   address      : IN     STD_LOGIC_VECTOR (HIGH_BIT downto 2);
   req_read      : IN     STD_LOGIC;
   req_write   : IN     STD_LOGIC;
   data_out      : OUT     STD_LOGIC_VECTOR (31 downto 0);
   data_out_valid : OUT     STD_LOGIC;
   data_in      : IN     STD_LOGIC_VECTOR (31 downto 0);
   data_mask    : in std_logic_vector(3 downto 0);
   tag_in       : in std_logic_vector(31 downto 0);
   tag_out       : out std_logic_vector(31 downto 0)
   );
  end component;

  signal sdr_address:    STD_LOGIC_VECTOR (HIGH_BIT downto 2);
  signal sdr_req_read      :     STD_LOGIC;
  signal sdr_req_write   :      STD_LOGIC;
  signal sdr_data_out      :      STD_LOGIC_VECTOR (31 downto 0);
  signal sdr_data_out_valid :      STD_LOGIC;
  signal sdr_data_in      : STD_LOGIC_VECTOR (31 downto 0);
  signal sdr_tag          : STD_LOGIC_VECTOR (31 downto 0);

  signal sdr_data_mask: std_logic_vector(3 downto 0);

  signal pending: std_logic;

begin

  ctrl: sdram_controller
    generic map (
      HIGH_BIT => HIGH_BIT,
      ADDRESS_BITS => 12
   )
   port map (
    clock_100   => wb_clk_i,
    clock_100_delayed_3ns => clk_off_3ns,
    rst => wb_rst_i,

    DRAM_ADDR   => DRAM_ADDR,
    DRAM_BA     => DRAM_BA,
    DRAM_CAS_N  => DRAM_CAS_N,
    DRAM_CKE    => DRAM_CKE,
    DRAM_CLK    => DRAM_CLK,
    DRAM_CS_N   => DRAM_CS_N,
    DRAM_DQ     => DRAM_DQ,
    DRAM_DQM    => DRAM_DQM,
    DRAM_RAS_N  => DRAM_RAS_N,
    DRAM_WE_N   => DRAM_WE_N,

    pending     => pending,
    address     => sdr_address,
    req_read    => sdr_req_read,
    req_write   => sdr_req_write,
    data_out    => sdr_data_out,
    data_out_valid => sdr_data_out_valid,
    data_in      => sdr_data_in,
    data_mask  => sdr_data_mask,
    tag_in      => wb_tag_i,
    tag_out     => sdr_tag
   );


  sdr_address(HIGH_BIT downto 2) <= wb_adr_i(HIGH_BIT downto 2);

  sdr_req_read<='1' when wb_cyc_i='1' and wb_stb_i='1' and wb_we_i='0' else '0';
  sdr_req_write<='1' when wb_cyc_i='1' and wb_stb_i='1' and wb_we_i='1' else '0';

  sdr_data_in <= wb_dat_i;
  sdr_data_mask <= wb_sel_i;

  wb_stall_o <= '1' when pending='1' else '0';

  resync: if true generate
  process(wb_clk_i)
  begin
    if rising_edge(wb_clk_i) then
     if wb_rst_i='1' then
       wb_ack_o <= '0';
     else
       wb_ack_o <= sdr_data_out_valid;
     end if;
     wb_dat_o <= sdr_data_out;
     wb_tag_o <= sdr_tag;
    end if;
  end process;
  end generate;

  noresync: if false generate
    wb_ack_o <= sdr_data_out_valid;
    wb_dat_o <= sdr_data_out;
    wb_tag_o <= sdr_tag;
  end generate;

  dbg.strobe <= ( not pending ) and wb_stb_i and wb_cyc_i;
  dbg.write  <= wb_we_i;
  dbg.address  <= unsigned(wb_adr_i);
  dbg.data  <= unsigned(wb_dat_i);
  dbg.pc  <= x"deadbeef";


end behave;



