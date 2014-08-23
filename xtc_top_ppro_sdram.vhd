library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.wishbonepkg.all;
use work.xtcpkg.all;
use work.xtccomppkg.all;

entity xtc_top_ppro_sdram is
  port (
    CLK:        in std_logic;

    -- Connection to the main SPI flash
    --SPI_SCK:    out std_logic;
    --SPI_MISO:   in std_logic;
    --SPI_MOSI:   out std_logic;
    --SPI_CS:     out std_logic;

    -- WING connections
    --WING_A:     inout std_logic_vector(15 downto 0);
    --WING_B:     inout std_logic_vector(15 downto 0);
    --WING_C:     inout std_logic_vector(15 downto 0);

    -- UART (FTDI) connection
    TXD:        out std_logic;
    RXD:        in std_logic;

    DRAM_ADDR   : OUT   STD_LOGIC_VECTOR (12 downto 0);
    DRAM_BA      : OUT   STD_LOGIC_VECTOR (1 downto 0);
    DRAM_CAS_N   : OUT   STD_LOGIC;
    DRAM_CKE      : OUT   STD_LOGIC;
    DRAM_CLK      : OUT   STD_LOGIC;
    DRAM_CS_N   : OUT   STD_LOGIC;
    DRAM_DQ      : INOUT STD_LOGIC_VECTOR(15 downto 0);
    DRAM_DQM      : OUT   STD_LOGIC_VECTOR(1 downto 0);
    DRAM_RAS_N   : OUT   STD_LOGIC;
    DRAM_WE_N    : OUT   STD_LOGIC;

    -- SPI flash
    MOSI:     out std_logic;
    MISO:     in std_logic;
    SCK:      out std_logic;
    NCS:      out std_logic

    -- The LED
    --LED:        out std_logic
  );
end entity xtc_top_ppro_sdram;

architecture behave of xtc_top_ppro_sdram is

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


  component clkgen is
  port (
    clkin:  in std_logic;
    rstin:  in std_logic;
    clkout: out std_logic;
    clkout1: out std_logic;
    clkout2: out std_logic;
    clkout2x: out std_logic;
    rstout: out std_logic
  );
  end component;

  signal sysrst:      std_logic;
  signal sysclk:      std_logic;
  signal clkgen_rst:  std_logic;
  signal wb_clk_i:    std_logic;
  signal wb_rst_i:    std_logic;

  component xtc_top_sdram is
  port (
    wb_syscon:      in wb_syscon_type;
    -- IO wishbone interface
    iowbo:           out wb_mosi_type;
    iowbi:           in wb_miso_type;
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
  end component;

  component xtc_serialreset is
  generic (
    SYSTEM_CLOCK_MHZ: integer := 100
  );
  port (
    clk:      in std_logic;
    rx:       in std_logic;
    rstin:    in std_logic;
    rstout:   out std_logic
  );
  end component;


  signal clk_off_3ns: std_ulogic;

  signal wbi: wb_mosi_type;
  signal wbo: wb_miso_type;
  signal syscon: wb_syscon_type;
  signal swbi: slot_wbi;
  signal swbo: slot_wbo;
  signal sids: slot_ids;

begin

  syscon.clk<=sysclk;
  syscon.rst<=sysrst;

  cpu: xtc_top_sdram
  port map (
    wb_syscon   => syscon,
    iowbi           => wbo,
    iowbo           => wbi,
        -- extra clocking
    clk_off_3ns => clk_off_3ns,

    -- SDRAM signals
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
  DRAM_ADDR(12)<='0';

  mosi <= '0';
  ncs  <= '1';
  sck <= '1';


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

      tx          => TXD,
      rx          => RXD
  );

  wb_clk_i <= sysclk;
  wb_rst_i <= sysrst;

  rstgen: xtc_serialreset
    generic map (
      SYSTEM_CLOCK_MHZ  => 96
    )
    port map (
      clk       => sysclk,
      rx        => RXD,
      rstin     => clkgen_rst,
      rstout    => sysrst
    );
  --sysrst <= clkgen_rst;

  clkgen_inst: clkgen
  port map (
    clkin   => clk,
    rstin   => '0'  ,
    clkout  => sysclk,
    clkout1  => clk_off_3ns,
    rstout  => clkgen_rst
  );

end behave;
