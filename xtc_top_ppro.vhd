library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.wishbonepkg.all;

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
    clkout2x: out std_logic;
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
    wb_syscon:      in wb_syscon_type;
    -- IO wishbone interface
    iowbo:           out wb_mosi_type;
    iowbi:           in wb_miso_type
  );
  end component;

  signal wb_read:    std_logic_vector(31 downto 0);
  signal wb_write:   std_logic_vector(31 downto 0);
  signal wb_address: std_logic_vector(31 downto 0);
  signal wb_tag_i:   std_logic_vector(31 downto 0);
  signal wb_tag_o:   std_logic_vector(31 downto 0);
  signal wb_stb:     std_logic;
  signal wb_cyc:     std_logic;
  signal wb_sel:     std_logic_vector(3 downto 0);
  signal wb_we:      std_logic;
  signal wb_ack:     std_logic;
  signal wb_int:     std_logic;
  signal wb_stall:     std_logic;
  signal wb_clk_i_2x: std_ulogic;

begin

  cpu: xtc_top_bram
  port map (
    wb_syscon.clk        => wb_clk_i,
    wb_syscon.rst        => wb_rst_i,

    -- Master wishbone interface
        
    iowbi.ack        => wb_ack,
    iowbi.dat        => wb_read,
    iowbi.tag        => wb_tag_i,
    iowbi.int        => wb_int,
    iowbi.stall      => '0',
    iowbo.dat        => wb_write,
    iowbo.adr        => wb_address,
    iowbo.cyc        => wb_cyc,
    iowbo.tag        => wb_tag_o,
    iowbo.stb        => wb_stb,
    iowbo.sel        => wb_sel,
    iowbo.we         => wb_we
  );


  -- Simple tag generator
  process(wb_clk_i)
  begin
    if rising_edge(wb_clk_i) then
       if wb_cyc='1' and wb_stb='1' and wb_ack='0' then
        wb_tag_o <= wb_tag_i;
       end if;
    end if;
  end process;

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
      wb_inta_o   => wb_int,
  
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
    clkout2x  => wb_clk_i_2x,
    rstout  => clkgen_rst
  );

end behave;
