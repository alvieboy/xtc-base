library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.wishbonepkg.all;
use work.xtcpkg.all;

entity xtc_top_ppro_sdram is
  port (
    CLK:        in std_logic;

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
    NCS:      out std_logic;

    --NNMI:     in std_logic;

    -- SD card
    SDMOSI:     out std_logic;
    SDMISO:     in std_logic;
    SDSCK:      out std_logic;
    SDNCS:      out std_logic;

    HSYNC:      out std_logic;
    VSYNC:      out std_logic;
    BLUE:       out std_logic_vector(3 downto 0);
    GREEN:      out std_logic_vector(3 downto 0);
    RED:        out std_logic_vector(3 downto 0);

    JOY_FIRE2:  in std_logic;
    JOY_FIRE1:  in std_logic;
    JOY_LEFT:   in std_logic;
    JOY_RIGHT:  in std_logic;
    JOY_SEL:    in std_logic;
    JOY_UP:     in std_logic;
    JOY_DOWN:   in std_logic;

    AUDIO:      out std_logic_vector(1 downto 0);

    RESET:      in std_logic

    -- The LED
    --LED:        out std_logic
  );
end entity xtc_top_ppro_sdram;

architecture behave of xtc_top_ppro_sdram is

  signal sysrst:      std_logic;
  signal sysclk:      std_logic;
  signal clkgen_rst:  std_logic;
  signal wb_clk_i:    std_logic;
  signal wb_rst_i:    std_logic;

  signal clk_off_3ns: std_ulogic;

  signal wbi: wb_mosi_type;
  signal wbo: wb_miso_type;
  signal dmawbi: wb_mosi_type;
  signal dmawbo: wb_miso_type;

  signal syscon: wb_syscon_type;
  signal swbi: slot_wbi;
  signal swbo: slot_wbo;
  signal sids: slot_ids;
  signal nmi, nmi_q, nmiack, rstreq,rstreq_q, do_reset: std_logic;
  signal vgaclk: std_logic;

begin

  AUDIO(0) <= '0';
  AUDIO(1) <= '0';

  process(sysclk)
  begin
    if rising_edge(sysclk) then
      if sysrst='1' then
        rstreq_q<='0';
      else
        rstreq_q<=rstreq;
      end if;
    end if;
  end process;

  do_reset<='1' when rstreq_q='0' and rstreq='1' else '0';


  syscon.clk<=sysclk;
  syscon.rst<=sysrst or do_reset;

  cpu: entity work.xtc_top_sdram
  port map (
    wb_syscon   => syscon,
    iowbi           => wbo,
    iowbo           => wbi,
    nmi             => nmi,
    nmiack          => nmiack,
    rstreq          => rstreq,

    dmawbi          => dmawbi,
    dmawbo          => dmawbo,
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
  --DRAM_ADDR(12)<='0';

  ioctrl: entity work.xtc_ioctrl
    port map (
      syscon      => syscon,
      wbi         => wbi,
      wbo         => wbo,
      swbi        => swbi,
      swbo        => swbo,
      sids        => sids
    );


  myrom: entity work.nodev
    port map (
      syscon      => syscon,
      wbi         => swbo(0),
      wbo         => swbi(0)
  );

  myuart: entity work.uart
    generic map (
      bits => 11
    )
    port map (
      syscon      => syscon,
      wbi         => swbo(1),
      wbo         => swbi(1),

      tx          => TXD,
      rx          => RXD
  );

  flashspi: entity work.spi
    generic map (
      INTERNAL_SPI => true
    )
    port map (
      syscon    => syscon,
      wbi       => swbo(2),
      wbo       => swbi(2),
      mosi      => MOSI,
      miso      => MISO,
      sck       => SCK,
      cs        => NCS
  );

  sdspi: entity work.spi
    generic map (
      INTERNAL_SPI => false
    )
    port map (
      syscon    => syscon,
      wbi       => swbo(3),
      wbo       => swbi(3),
      mosi      => SDMOSI,
      miso      => SDMISO,
      sck       => SDSCK,
      cs        => SDNCS
  );

  vgaenabled: if false generate

  vga: entity work.vga_320_240_idx
  port map (
    wb_clk_i  => syscon.clk,
	 	wb_rst_i  => syscon.rst,
    wb_dat_o  => swbi(4).dat,
    wb_dat_i  => swbo(4).dat,
    wb_adr_i  => swbo(4).adr(31 downto 2),
    wb_we_i   => swbo(4).we,
    wb_cyc_i  => swbo(4).cyc,
    wb_stb_i  => swbo(4).stb,
    wb_ack_o  => swbi(4).ack,

    -- Wishbone MASTER interface
    mi_wb_dat_i => dmawbo.dat,
    mi_wb_dat_o => dmawbi.dat,
    mi_wb_adr_o => dmawbi.adr,
    mi_wb_sel_o => dmawbi.sel,
    --mi_wb_cti_o => dmawbi.cti,
    mi_wb_we_o  => dmawbi.we,
    mi_wb_cyc_o => dmawbi.cyc,
    mi_wb_stb_o => dmawbi.stb,
    mi_wb_ack_i => dmawbo.ack,
    mi_wb_stall_i => dmawbo.stall,

    -- VGA signals
    vgaclk      => vgaclk,
    vga_hsync   => HSYNC,
    vga_vsync   => VSYNC,
    vga_b(0)    => open,
    vga_b(4 downto 1)       => BLUE,
    vga_r(0)    => open,
    vga_r(4 downto 1)       => RED,
    vga_g(0)    => open,
    vga_g(4 downto 1)       => GREEN,
    blank       => open
  );
  end generate;


  vgadisabled: if true generate
    eslot: entity work.sinkdev
      port map (
        syscon    => syscon,
        wbi       => swbo(4),
        wbo       => swbi(4)
     );
    dmawbi.dat <= (others => 'X');
    dmawbi.adr <= (others => 'X');
    dmawbi.sel <= (others => 'X');
    dmawbi.we <='0';
    dmawbi.cyc<='0';
    dmawbi.stb<='0';
    RED<=(others => '0');
    GREEN<=(others => '0');
    BLUE<=(others => '0');
    HSYNC<='0';
    VSYNC<='0';

  end generate;

  emptyslots: for N in 5 to 15 generate
    eslot: entity work.nodev
      port map (
        syscon    => syscon,
        wbi       => swbo(N),
        wbo       => swbi(N)
     );
    --swbi(N) <= wb_miso_default;
  end generate;

  wb_clk_i <= sysclk;
  wb_rst_i <= sysrst;

  rstgen: entity work.xtc_serialreset
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

  clkgen_inst: entity work.clkgen
  port map (
    clkin   => clk,
    rstin   => '0'  ,
    clkout  => sysclk,
    clkout1  => clk_off_3ns,
    vgaclk => vgaclk,
    rstout  => clkgen_rst
  );

  -- NMI
  process (sysclk)
  begin
    if rising_edge(sysclk) then
      if sysrst='1' then
        nmi <= '0';
      else
        if RESET='1' then
          nmi<='1';
        elsif nmiack='1' then
          nmi<='0';
        end if;
      end if;
    end if;
  end process;

end behave;
