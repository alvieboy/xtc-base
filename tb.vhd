library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.newcpupkg.all;
use work.newcpucomppkg.all;
use work.wishbonepkg.all;

entity tb is
end entity tb;

architecture sim of tb is

  constant period: time := 10 ns;
  signal w_clk: std_logic := '0';
  signal w_rst: std_logic := '0';

  signal wb_read:    std_logic_vector(31 downto 0);
  signal wb_write:   std_logic_vector(31 downto 0);
  signal wb_address: std_logic_vector(31 downto 0);
  signal wb_stb:     std_logic;
  signal wb_cyc:     std_logic;
  signal wb_sel:     std_logic_vector(3 downto 0);
  signal wb_we:      std_logic;
  signal wb_ack:     std_logic;

  signal rom_wb_ack:       std_logic;
  signal rom_wb_read:      std_logic_vector(31 downto 0);
  signal rom_wb_adr:       std_logic_vector(31 downto 0);
  signal rom_wb_cyc:       std_logic;
  signal rom_wb_stb:       std_logic;
  signal rom_wb_cti:       std_logic_vector(2 downto 0);
  signal rom_wb_stall:     std_logic;

  signal p_cpu_ram_wb_clk_i:       std_logic;
  signal p_cpu_ram_wb_rst_i:       std_logic;
  signal p_cpu_ram_wb_ack_o:       std_logic;
  signal p_cpu_ram_wb_stall_o:     std_logic;
  signal p_cpu_ram_wb_dat_i:       std_logic_vector(31 downto 0);
  signal p_cpu_ram_wb_dat_o:       std_logic_vector(31 downto 0);
  signal p_cpu_ram_wb_adr_i:       std_logic_vector(31 downto 0);
  signal p_cpu_ram_wb_cyc_i:       std_logic;
  signal p_cpu_ram_wb_stb_i:       std_logic;
  signal p_cpu_ram_wb_sel_i:       std_logic_vector(3 downto 0);
  signal p_cpu_ram_wb_we_i:        std_logic;


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

  signal sysclk_sram_we: std_logic;

  signal sram_wb_ack_o:       std_logic;
  signal sram_wb_dat_i:       std_logic_vector(31 downto 0);
  signal sram_wb_dat_o:       std_logic_vector(31 downto 0);
  signal sram_wb_adr_i:       std_logic_vector(31 downto 0);
  signal sram_wb_cyc_i:       std_logic;
  signal sram_wb_stb_i:       std_logic;
  signal sram_wb_we_i:        std_logic;
  signal sram_wb_sel_i:       std_logic_vector(3 downto 0);
  signal sram_wb_stall_o:     std_logic;

  component sdram_ctrl is
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;

    wb_dat_o: out std_logic_vector(31 downto 0);
    wb_dat_i: in std_logic_vector(31 downto 0);
    wb_adr_i: in std_logic_vector(31 downto 2);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_sel_i: in std_logic_vector(3 downto 0);
    wb_ack_o: out std_logic;
    wb_stall_o: out std_logic;

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

end component sdram_ctrl;

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


begin

  w_clk <= not w_clk after period/2;

  cpu: newcpu
  port map (
    wb_clk_i        => w_clk,
    wb_rst_i        => w_rst,

    -- Master wishbone interface

    wb_ack_i        => wb_ack,
    wb_dat_i        => wb_read,
    wb_dat_o        => wb_write,
    wb_adr_o        => wb_address,
    wb_cyc_o        => wb_cyc,
    wb_stb_o        => wb_stb,
    wb_sel_o        => wb_sel,
    wb_we_o         => wb_we,
      -- ROM wb interface

    rom_wb_ack_i    => rom_wb_ack,
    rom_wb_dat_i    => rom_wb_read,
    rom_wb_adr_o    => rom_wb_adr,
    rom_wb_cyc_o    => rom_wb_cyc,
    rom_wb_stb_o    => rom_wb_stb,
    rom_wb_cti_o    => rom_wb_cti,
    rom_wb_stall_i  => rom_wb_stall,

    wb_inta_i       => '0',
    isnmi           => '0'
  );

  -- Reset procedure
  process
  begin
    w_rst<='0';
    wait for period;
    w_rst<='1';
    wait for period;
    w_rst<='0';
    wait;
  end process;


  npnadapt: wb_master_np_to_slave_p
  generic map (
    ADDRESS_HIGH  => 31,
    ADDRESS_LOW   => 0
  )
  port map (
    wb_clk_i    => w_clk,
	 	wb_rst_i    => w_rst,

    -- Master signals

    m_wb_dat_o  => wb_read,
    m_wb_dat_i  => wb_write,
    m_wb_adr_i  => wb_address,
    m_wb_sel_i  => wb_sel,
    m_wb_cti_i  => CTI_CYCLE_CLASSIC,
    m_wb_we_i   => wb_we,
    m_wb_cyc_i  => wb_cyc,
    m_wb_stb_i  => wb_stb,
    m_wb_ack_o  => wb_ack,

    -- Slave signals

    s_wb_dat_i  => p_cpu_ram_wb_dat_o,
    s_wb_dat_o  => p_cpu_ram_wb_dat_i,
    s_wb_adr_o  => p_cpu_ram_wb_adr_i,
    s_wb_sel_o  => p_cpu_ram_wb_sel_i,
    s_wb_cti_o  => open,
    s_wb_we_o   => p_cpu_ram_wb_we_i,
    s_wb_cyc_o  => p_cpu_ram_wb_cyc_i,
    s_wb_stb_o  => p_cpu_ram_wb_stb_i,
    s_wb_ack_i  => p_cpu_ram_wb_ack_o,
    s_wb_stall_i => p_cpu_ram_wb_stall_o
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


  sysclk_sram_we <= transport w_clk after 3 ns;


  sram_inst: sdram_ctrl
    port map (
      wb_clk_i    => w_clk,
  	 	wb_rst_i    => w_rst,
      wb_dat_o    => sram_wb_dat_o,
      wb_dat_i    => sram_wb_dat_i,
      wb_adr_i    => sram_wb_adr_i(31 downto 2),
      wb_we_i     => sram_wb_we_i,
      wb_cyc_i    => sram_wb_cyc_i,
      wb_stb_i    => sram_wb_stb_i,
      wb_sel_i    => sram_wb_sel_i,
      --wb_cti_i    => CTI_CYCLE_CLASSIC,
      wb_ack_o    => sram_wb_ack_o,
      wb_stall_o  => sram_wb_stall_o,

      clk_off_3ns => sysclk_sram_we,
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
    DRAM_ADDR(12) <= '0';

  memarb2: wbarb2_1
  generic map (
    ADDRESS_HIGH => 31,
    ADDRESS_LOW => 0
  )
  port map (
    wb_clk_i      => w_clk,
	 	wb_rst_i      => w_rst,

    -- Master 0 signals (CPU)

    m0_wb_dat_o   => p_cpu_ram_wb_dat_o,
    m0_wb_dat_i   => p_cpu_ram_wb_dat_i,
    m0_wb_adr_i   => p_cpu_ram_wb_adr_i(31 downto 0),
    m0_wb_sel_i   => p_cpu_ram_wb_sel_i,
    m0_wb_cti_i   => CTI_CYCLE_CLASSIC,
    m0_wb_we_i    => p_cpu_ram_wb_we_i,
    m0_wb_cyc_i   => p_cpu_ram_wb_cyc_i,
    m0_wb_stb_i   => p_cpu_ram_wb_stb_i,
    m0_wb_ack_o   => p_cpu_ram_wb_ack_o,
    m0_wb_stall_o => p_cpu_ram_wb_stall_o,

    -- Master 1 signals

    m1_wb_dat_o   => rom_wb_read,
    m1_wb_dat_i   => (others =>'0'),
    m1_wb_adr_i   => rom_wb_adr,
    m1_wb_sel_i   => (others => '1'),
    m1_wb_cti_i   => CTI_CYCLE_CLASSIC,
    m1_wb_we_i    => '0',
    m1_wb_cyc_i   => rom_wb_cyc,
    m1_wb_stb_i   => rom_wb_stb,
    m1_wb_ack_o   => rom_wb_ack,
    m1_wb_stall_o   => rom_wb_stall,

    -- Slave signals

    s0_wb_dat_i   => sram_wb_dat_o,
    s0_wb_dat_o   => sram_wb_dat_i,
    s0_wb_adr_o   => sram_wb_adr_i(31 downto 0),
    s0_wb_sel_o   => sram_wb_sel_i,
    s0_wb_cti_o   => open,
    s0_wb_we_o    => sram_wb_we_i,
    s0_wb_cyc_o   => sram_wb_cyc_i,
    s0_wb_stb_o   => sram_wb_stb_i,
    s0_wb_ack_i   => sram_wb_ack_o,
    s0_wb_stall_i => sram_wb_stall_o
  );


end sim;
