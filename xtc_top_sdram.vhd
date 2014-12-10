library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.xtcpkg.all;
use work.xtccomppkg.all;
use work.wishbonepkg.all;

entity xtc_top_sdram is
  port (
    wb_syscon:      in wb_syscon_type;
    -- IO wishbone interface
    iowbo:           out wb_mosi_type;
    iowbi:           in wb_miso_type;
    nmi:              in std_logic;
    nmiack:           out std_logic;
    rstreq:           out std_logic;
    -- SDRAM signals
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
end entity;

architecture behave of xtc_top_sdram is


  signal wb_read:       std_logic_vector(31 downto 0);
  signal wb_write:      std_logic_vector(31 downto 0);
  signal wb_address:    std_logic_vector(31 downto 0);
  signal wb_tago:       std_logic_vector(31 downto 0);
  signal wb_tagi:       std_logic_vector(31 downto 0);
  signal wb_stb:        std_logic;
  signal wb_cyc:        std_logic;
  signal wb_sel:        std_logic_vector(3 downto 0);
  signal wb_we:         std_logic;
  signal wb_ack:        std_logic;
  signal wb_stall:      std_logic;

  --signal rstreq:        std_logic;

  component sdram_ctrl is
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

    dbg:      out memory_debug_type;
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
  end component;

  signal wbo,romwbo,ramwbo,piowbo,sdram_wbo: wb_mosi_type;
  signal wbi,romwbi,ramwbi,piowbi,sdram_wbi: wb_miso_type;
  signal edbg: memory_debug_type;

begin

  sdram_wbi.err <= '0';
  sdram_wbi.int <= '0';

  cpu: xtc
  port map (
    wb_syscon       => wb_syscon,
    -- Master wishbone interface
    wbo             => ramwbo,
    wbi             => ramwbi,
    -- ROM wb interface
    romwbo          => romwbo,
    romwbi          => romwbi,
    nmi             => nmi,
    nmiack          => nmiack,
    rstreq          => rstreq,
    edbg            => edbg
  );

  muxer: xtc_wbmux2
  generic map (
    select_line   => 31,
    address_high  => 31,
    address_low   => 2
  )
  port map (
    wb_syscon     => wb_syscon,
    -- Master 
    m_wbi         => wbo,
    m_wbo         => wbi,

    -- Slave 0 signals
    s0_wbi        => sdram_wbi,
    s0_wbo        => sdram_wbo,

    -- Slave 0 signals
    s1_wbi        => piowbi,
    s1_wbo        => piowbo
  );

  ramwbi.int <= iowbi.int;

  maccarb: wbarb2_1
  port map (
    wb_syscon     => wb_syscon,
    -- Master 0 signals
    m0_wbi        => ramwbo,
    m0_wbo        => ramwbi,
    -- Master 1 signals
    m1_wbi        => romwbo,
    m1_wbo        => romwbi,

    -- Slave signals
    s0_wbi        => wbi,
    s0_wbo        => wbo
  );


  ioadaptor: wb_master_p_to_slave_np
  port map (
    syscon      => wb_syscon,
    mwbo        => piowbi,
    mwbi        => piowbo,
    swbi        => iowbi,
    swbo        => iowbo
  );

  sdramcrtl_inst: sdram_ctrl
  generic map (
    HIGH_BIT => 22
  )
  port map (
    wb_clk_i    => wb_syscon.clk,
	 	wb_rst_i    => wb_syscon.rst,

    wb_dat_o    => sdram_wbi.dat,
    wb_dat_i    => sdram_wbo.dat,
    wb_adr_i    => sdram_wbo.adr,
    wb_we_i     => sdram_wbo.we,
    wb_cyc_i    => sdram_wbo.cyc,
    wb_stb_i    => sdram_wbo.stb,
    wb_sel_i    => sdram_wbo.sel,
    wb_tag_i    => sdram_wbo.tag,
    wb_ack_o    => sdram_wbi.ack,
    wb_stall_o  => sdram_wbi.stall,
    wb_tag_o    => sdram_wbi.tag,

    dbg => edbg,

    -- extra clocking
    clk_off_3ns => clk_off_3ns,

    -- SDRAM signals
    DRAM_ADDR   => DRAM_ADDR,
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

end behave;
