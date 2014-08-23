library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.xtcpkg.all;
use work.xtccomppkg.all;
use work.wishbonepkg.all;

entity tb_sdram_flash is
end entity tb_sdram_flash;

architecture sim of tb_sdram_flash is

  constant period: time := 10 ns;--9.615 ns;
  signal w_clk: std_logic := '0';
  signal w_clk_2x: std_logic := '1';
  signal w_rst: std_logic := '0';


  component wbarb2_1 is
  generic (
    ADDRESS_HIGH: integer := 31;
    ADDRESS_LOW: integer := 0
  );
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;

    -- Master 0 signals

    m0_wb_dat_o: out std_logic_vector(31 downto 0);
    m0_wb_dat_i: in std_logic_vector(31 downto 0);
    m0_wb_adr_i: in std_logic_vector(ADDRESS_HIGH downto ADDRESS_LOW);
    m0_wb_sel_i: in std_logic_vector(3 downto 0);
    m0_wb_cti_i: in std_logic_vector(2 downto 0);
    m0_wb_we_i:  in std_logic;
    m0_wb_cyc_i: in std_logic;
    m0_wb_stb_i: in std_logic;
    m0_wb_stall_o: out std_logic;
    m0_wb_ack_o: out std_logic;

    -- Master 1 signals

    m1_wb_dat_o: out std_logic_vector(31 downto 0);
    m1_wb_dat_i: in std_logic_vector(31 downto 0);
    m1_wb_adr_i: in std_logic_vector(ADDRESS_HIGH downto ADDRESS_LOW);
    m1_wb_sel_i: in std_logic_vector(3 downto 0);
    m1_wb_cti_i: in std_logic_vector(2 downto 0);
    m1_wb_we_i:  in std_logic;
    m1_wb_cyc_i: in std_logic;
    m1_wb_stb_i: in std_logic;
    m1_wb_ack_o: out std_logic;
    m1_wb_stall_o: out std_logic;

    -- Slave signals

    s0_wb_dat_i: in std_logic_vector(31 downto 0);
    s0_wb_dat_o: out std_logic_vector(31 downto 0);
    s0_wb_adr_o: out std_logic_vector(ADDRESS_HIGH downto ADDRESS_LOW);
    s0_wb_sel_o: out std_logic_vector(3 downto 0);
    s0_wb_cti_o: out std_logic_vector(2 downto 0);
    s0_wb_we_o:  out std_logic;
    s0_wb_cyc_o: out std_logic;
    s0_wb_stb_o: out std_logic;
    s0_wb_ack_i: in std_logic;
    s0_wb_stall_i: in std_logic
  );
  end component;

  component wb_singleport_ram is
  generic (
    bits: natural := 8
  );
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;
    wb_dat_o: out std_logic_vector(31 downto 0);
    wb_dat_i: in std_logic_vector(31 downto 0);
    wb_adr_i: in std_logic_vector(31 downto 0);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;
    wb_inta_o:out std_logic
  );
  end component;

  component wb_master_np_to_slave_p is
  generic (
    ADDRESS_HIGH: integer := 31;
    ADDRESS_LOW: integer := 0
  );
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;

    -- Master signals

    m_wb_dat_o: out std_logic_vector(31 downto 0);
    m_wb_dat_i: in std_logic_vector(31 downto 0);
    m_wb_adr_i: in std_logic_vector(ADDRESS_HIGH downto ADDRESS_LOW);
    m_wb_sel_i: in std_logic_vector(3 downto 0);
    m_wb_cti_i: in std_logic_vector(2 downto 0);
    m_wb_we_i:  in std_logic;
    m_wb_cyc_i: in std_logic;
    m_wb_stb_i: in std_logic;
    m_wb_ack_o: out std_logic;

    -- Slave signals

    s_wb_dat_i: in std_logic_vector(31 downto 0);
    s_wb_dat_o: out std_logic_vector(31 downto 0);
    s_wb_adr_o: out std_logic_vector(ADDRESS_HIGH downto ADDRESS_LOW);
    s_wb_sel_o: out std_logic_vector(3 downto 0);
    s_wb_cti_o: out std_logic_vector(2 downto 0);
    s_wb_we_o:  out std_logic;
    s_wb_cyc_o: out std_logic;
    s_wb_stb_o: out std_logic;
    s_wb_ack_i: in std_logic;
    s_wb_stall_i: in std_logic
  );
  end component;

  component spirom is
  port (
    syscon:     in wb_syscon_type;
    wbi:        in wb_mosi_type;
    wbo:        out wb_miso_type;

    mosi:     out std_logic;
    miso:     in  std_logic;
    sck:      out std_logic;
    ncs:      out std_logic
  );
  end component;

  component bootrom is
  port (
    syscon:     in wb_syscon_type;
    wbi:        in wb_mosi_type;
    wbo:        out wb_miso_type
  );
  end component;

  
  component uart is
  generic (
    bits: integer := 11
  );
  port (
    syscon:     in wb_syscon_type;
    wbi:        in wb_mosi_type;
    wbo:        out wb_miso_type;
    tx:       out std_logic;
    rx:       in std_logic
  );
  end component;

 -- SDRAM signals
  signal DRAM_ADDR   :    STD_LOGIC_VECTOR (12 downto 0);
  signal DRAM_BA      :   STD_LOGIC_VECTOR (1 downto 0);
  signal DRAM_CAS_N   :    STD_LOGIC;
  signal DRAM_CKE      :    STD_LOGIC;
  signal DRAM_CLK      :   STD_LOGIC;
  signal DRAM_CS_N   :    STD_LOGIC;
  signal DRAM_DQ      :  STD_LOGIC_VECTOR(15 downto 0);
  signal DRAM_DQM      :   STD_LOGIC_VECTOR(1 downto 0);
  signal DRAM_RAS_N   :   STD_LOGIC;
  signal DRAM_WE_N    :   STD_LOGIC;

  component mt48lc16m16a2 IS
    GENERIC (
        -- Timing Parameters for -7E (PC133) and CAS Latency = 3
        tAC       : TIME    :=  5.4 ns;
        tHZ       : TIME    :=  7.0 ns;
        tOH       : TIME    :=  2.7 ns;
        tMRD      : INTEGER :=  2;          -- 2 Clk Cycles
        tRAS      : TIME    := 44.0 ns;
        tRC       : TIME    := 66.0 ns;
        tRCD      : TIME    := 20.0 ns;
        tRP       : TIME    := 20.0 ns;
        tRRD      : TIME    := 15.0 ns;
        tWRa      : TIME    :=  7.5 ns;     -- A2 Version - Auto precharge mode only (1 Clk + 7.5 ns)
        tWRp      : TIME    := 15.0 ns;     -- A2 Version - Precharge mode only (15 ns)

        tAH       : TIME    :=  0.8 ns;
        tAS       : TIME    :=  1.5 ns;
        tCH       : TIME    :=  2.5 ns;
        tCL       : TIME    :=  2.5 ns;
        tCK       : TIME    :=  7.0 ns;
        tDH       : TIME    :=  0.8 ns;
        tDS       : TIME    :=  1.5 ns;
        tCKH      : TIME    :=  0.8 ns;
        tCKS      : TIME    :=  1.5 ns;
        tCMH      : TIME    :=  0.8 ns;
        tCMS      : TIME    :=  1.5 ns;

        addr_bits : INTEGER := 13;
        data_bits : INTEGER := 16;
        col_bits  : INTEGER :=  9;
        index     : INTEGER :=  0;
	fname     : string := "sdram.srec"	-- File to read from
    );
    PORT (
        Dq    : INOUT STD_LOGIC_VECTOR (data_bits - 1 DOWNTO 0) := (OTHERS => 'Z');
        Addr  : IN    STD_LOGIC_VECTOR (addr_bits - 1 DOWNTO 0) := (OTHERS => '0');
        Ba    : IN    STD_LOGIC_VECTOR := "00";
        Clk   : IN    STD_LOGIC := '0';
        Cke   : IN    STD_LOGIC := '1';
        Cs_n  : IN    STD_LOGIC := '1';
        Ras_n : IN    STD_LOGIC := '1';
        Cas_n : IN    STD_LOGIC := '1';
        We_n  : IN    STD_LOGIC := '1';
        Dqm   : IN    STD_LOGIC_VECTOR (1 DOWNTO 0) := "00"
    );
  END component;

  component M25P16 IS

  GENERIC (	init_file: string := string'("initM25P16.txt");         -- Init file name
		SIZE : positive := 1048576*16;                          -- 16Mbit
		Plength : positive := 256;                              -- Page length (in Byte)
		SSIZE : positive := 524288;                             -- Sector size (in # of bits)
		NB_BPi: positive := 3;                                  -- Number of BPi bits
		signature : STD_LOGIC_VECTOR (7 downto 0):="00010100";  -- Electronic signature
		manufacturerID : STD_LOGIC_VECTOR (7 downto 0):="00100000"; -- Manufacturer ID
		memtype : STD_LOGIC_VECTOR (7 downto 0):="00100000"; -- Memory Type
		density : STD_LOGIC_VECTOR (7 downto 0):="00010101"; -- Density 
		Tc: TIME := 20 ns;                                      -- Minimum Clock period
		Tr: TIME := 50 ns;                                      -- Minimum Clock period for read instruction
		tSLCH: TIME:= 5 ns;                                    -- notS active setup time (relative to C)
		tCHSL: TIME:= 5 ns;                                    -- notS not active hold time
		tCH : TIME := 9 ns;                                    -- Clock high time
		tCL : TIME := 9 ns;                                    -- Clock low time
		tDVCH: TIME:= 2 ns;                                     -- Data in Setup Time
		tCHDX: TIME:= 5 ns;                                     -- Data in Hold Time
		tCHSH : TIME := 5 ns;                                  -- notS active hold time (relative to C)
	 	tSHCH: TIME := 5 ns;                                   -- notS not active setup  time (relative to C)
		tSHSL: TIME := 100 ns;                                  -- /S deselect time
		tSHQZ: TIME := 8 ns;                                   -- Output disable Time
		tCLQV: TIME := 8 ns;                                   -- clock low to output valid
		tHLCH: TIME := 5 ns;                                   -- NotHold active setup time
		tCHHH: TIME := 5 ns;                                   -- NotHold not active hold time
		tHHCH: TIME := 5 ns;                                   -- NotHold not active setup time
		tCHHL: TIME := 5 ns;                                   -- NotHold active hold time
		tHHQX: TIME := 8 ns;                                   -- NotHold high to Output Low-Z
		tHLQZ: TIME := 8 ns;                                   -- NotHold low to Output High-Z
	  tWHSL: TIME := 20 ns;                                   -- Write protect setup time (SRWD=1)
	  tSHWL: TIME := 100 ns;                                 -- Write protect hold time (SRWD=1)
		tDP: TIME := 3 us;                                      -- notS high to deep power down mode
		tRES1: TIME := 30 us;                                    -- notS high to stand-by power mode
		tRES2: TIME := 30 us;                                  --
		tW: TIME := 15 ms;                                      -- write status register cycle time
		tPP: TIME := 5 ms;                                      -- page program cycle time
		tSE: TIME := 10 us;--3 sec;                                     -- sector erase cycle time
		tBE: TIME := 30 us;--40 sec;                                    -- bulk erase cycle time
		tVSL: TIME := 10 us;                                    -- Vcc(min) to /S low
		tPUW: TIME := 10 ms;                                    -- Time delay to write instruction
		Vwi: REAL := 2.5 ;                                      -- Write inhibit voltage (unit: V)
		Vccmin: REAL := 2.7 ;                                   -- Minimum supply voltage
		Vccmax: REAL := 3.6                                     -- Maximum supply voltage
		);

    PORT(		VCC: IN REAL;
		  C, D, S, W, HOLD : IN std_logic ;
		  Q : OUT std_logic);
  end component;

  signal txd, rxd: std_logic;
  signal w_clk_3ns: std_logic;

  signal miso, mosi, sck, sel: std_logic;
  signal vcc: real := 0.0;
  signal wbi: wb_mosi_type;
  signal wbo: wb_miso_type;
  signal syscon: wb_syscon_type;
  signal swbi: slot_wbi;
  signal swbo: slot_wbo;
  signal sids: slot_ids
  ;
begin

  rxd <= '1';

  w_clk <= not w_clk after period/2;
  w_clk_3ns<=transport w_clk after 3 ns;
  wbo.stall <= '0';

  syscon.clk<=w_clk;
  syscon.rst<=w_rst;

  cpu: xtc_top_sdram
  port map (
    wb_syscon   => syscon,
    -- Master wishbone interface
    iowbi           => wbo,
    iowbo           => wbi,

    clk_off_3ns     => w_clk_3ns,

    DRAM_ADDR   => DRAM_ADDR(11 downto 0),
    DRAM_BA     => DRAM_BA,
    DRAM_CAS_N  => DRAM_CAS_N,
    DRAM_CKE    => DRAM_CKE,
    DRAM_CLK    => DRAM_CLK,
    DRAM_CS_N   => DRAM_CS_N,
    DRAM_DQ     => DRAM_DQ,
    DRAM_DQM    => DRAM_DQM,
    DRAM_RAS_N  => DRAM_RAS_N,
    DRAM_WE_N   => DRAM_WE_N

  );

  sdram: mt48lc16m16a2
    GENERIC MAP  (
        addr_bits  => 12,
        data_bits  => 16,
        col_bits   => 8,
        index      => 0,
      	fname      => "sdram.srec"
    )
    PORT MAP (
        Dq    => DRAM_DQ,
        Addr  => DRAM_ADDR(11 downto 0),
        Ba    => DRAM_BA,
        Clk   => DRAM_CLK,
        Cke   => DRAM_CKE,
        Cs_n  => DRAM_CS_N,
        Ras_n => DRAM_RAS_N,
        Cas_n => DRAM_CAS_N,
        We_n  => DRAM_WE_N,
        Dqm   => DRAM_DQM
    );

  ioctrl: xtc_ioctrl
    port map (
      syscon      => syscon,
      wbi         => wbi,
      wbo         => wbo,
      swbi        => swbi,
      swbo        => swbo,
      sids        => sids
    );


  myrom: bootrom
    port map (
      syscon      => syscon,
      wbi         => swbo(0),
      wbo         => swbi(0)
  );

  myuart: uart
    port map (
      syscon      => syscon,
      wbi         => swbo(1),
      wbo         => swbi(1),

      tx          => open,
      rx          => 'X'
  );

  
  flash: M25P16
    PORT map (
		  VCC   => vcc,
		  C     => sck,
      D     => mosi,
      S     => sel,
      W     => '1',
      HOLD  => '1',
		  Q     => miso);

  vcc<=3.3 after 10 ns;

  -- Reset procedure
  process
  begin
    w_rst<='0';
    wait for period;
    w_rst<='1';
    wait for period;
    w_rst<='0';
    --wait for 10 us;
    --w_rst<='1';
    --wait for period;
    --w_rst<='0';
    wait;
  end process;

  -- Interrupt test
  process
  begin
    wait for 310 ns;
--    wb_int <= '1';
    wait for 50 ns;
  --  wb_int <= '0';

  end process;

end sim;
