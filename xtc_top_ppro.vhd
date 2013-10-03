library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity xtc_top_ppro is
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
    RXD:        in std_logic

    --DRAM_ADDR   : OUT   STD_LOGIC_VECTOR (12 downto 0);
    -- DRAM_BA      : OUT   STD_LOGIC_VECTOR (1 downto 0);
    -- DRAM_CAS_N   : OUT   STD_LOGIC;
    -- DRAM_CKE      : OUT   STD_LOGIC;
    -- DRAM_CLK      : OUT   STD_LOGIC;
    -- DRAM_CS_N   : OUT   STD_LOGIC;
    -- DRAM_DQ      : INOUT STD_LOGIC_VECTOR(15 downto 0);
   --  DRAM_DQM      : OUT   STD_LOGIC_VECTOR(1 downto 0);
   --  DRAM_RAS_N   : OUT   STD_LOGIC;
    -- DRAM_WE_N    : OUT   STD_LOGIC;

    -- The LED
    --LED:        out std_logic
  );
end entity xtc_top_ppro;

architecture behave of xtc_top_ppro is

  component uart is
  generic (
    bits: integer := 11
  );
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;
    wb_dat_o: out std_logic_vector(31 downto 0);
    wb_dat_i: in std_logic_vector(31 downto 0);
    wb_adr_i: in std_logic_vector(31 downto 2);
    wb_we_i:  in std_logic;
    wb_cyc_i: in std_logic;
    wb_stb_i: in std_logic;
    wb_ack_o: out std_logic;
    wb_inta_o:out std_logic;

    enabled:  out std_logic;
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
    rstout: out std_logic
  );
  end component;

  signal sysrst:      std_logic;
  signal sysclk:      std_logic;
  signal clkgen_rst:  std_logic;
  signal wb_clk_i:    std_logic;
  signal wb_rst_i:    std_logic;

  component xtc_top_bram is
  port (
    wb_clk_i:       in std_logic;
    wb_rst_i:       in std_logic;

    -- IO wishbone interface

    wb_ack_i:       in std_logic;
    wb_dat_i:       in std_logic_vector(31 downto 0);
    wb_dat_o:       out std_logic_vector(31 downto 0);
    wb_adr_o:       out std_logic_vector(31 downto 0);
    wb_cyc_o:       out std_logic;
    wb_stb_o:       out std_logic;
    wb_sel_o:       out std_logic_vector(3 downto 0);
    wb_we_o:        out std_logic

  );
  end component;

  signal wb_read:    std_logic_vector(31 downto 0);
  signal wb_write:   std_logic_vector(31 downto 0);
  signal wb_address: std_logic_vector(31 downto 0);
  signal wb_stb:     std_logic;
  signal wb_cyc:     std_logic;
  signal wb_sel:     std_logic_vector(3 downto 0);
  signal wb_we:      std_logic;
  signal wb_ack:     std_logic;
  signal wb_stall:     std_logic;

begin

  cpu: xtc_top_bram
  port map (
    wb_clk_i        => wb_clk_i,
    wb_rst_i        => wb_rst_i,

    -- Master wishbone interface

    wb_ack_i        => wb_ack,
    wb_dat_i        => wb_read,
    wb_dat_o        => wb_write,
    wb_adr_o        => wb_address,
    wb_cyc_o        => wb_cyc,
    wb_stb_o        => wb_stb,
    wb_sel_o        => wb_sel,
    wb_we_o         => wb_we
  );

  myuart: uart
    port map (
      wb_clk_i    => wb_clk_i,
      wb_rst_i    => wb_rst_i,
      wb_dat_o    => wb_read,
      wb_dat_i    => wb_write,
      wb_adr_i    => wb_address(31 downto 2),
      wb_we_i     => wb_we,
      wb_cyc_i    => wb_cyc,
      wb_stb_i    => wb_stb,
      wb_ack_o    => wb_ack,
      wb_inta_o   => open,
  
      tx          => txd,
      rx          => rxd
  );

  wb_clk_i <= sysclk;
  wb_rst_i <= sysrst;

--  rstgen: zpuino_serialreset
--    generic map (
--      SYSTEM_CLOCK_MHZ  => 96
--    )
--    port map (
--      clk       => sysclk,
--      rx        => rx,
--      rstin     => clkgen_rst,
--      rstout    => sysrst
--    );
  sysrst <= clkgen_rst;

  clkgen_inst: clkgen
  port map (
    clkin   => clk,
    rstin   => '0'  ,
    clkout  => sysclk,
    rstout  => clkgen_rst
  );

end behave;
