library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.xtcpkg.all;
use work.wishbonepkg.all;

entity tb_sdram_flash is
end entity tb_sdram_flash;

architecture sim of tb_sdram_flash is

  constant period: time := 10 ns;--9.615 ns;
  signal w_clk: std_logic := '0';
  signal w_clk_2x: std_logic := '1';
  signal w_rst: std_logic := '0';

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

  signal txd, rxd: std_logic;
  signal w_clk_3ns: std_logic;

  signal miso, mosi, sck, sel: std_logic;
  signal vcc: real := 0.0;
  signal wbi: wb_mosi_type;
  signal wbo: wb_miso_type;
  signal syscon: wb_syscon_type;
  signal swbi: slot_wbi;
  signal swbo: slot_wbo;
  signal sids: slot_ids;
  signal nmi, nmiack: std_logic;
  
begin

  rxd <= '1';

  w_clk <= not w_clk after period/2;
  w_clk_3ns<=transport w_clk after 3 ns;
  wbo.stall <= '0';

  syscon.clk<=w_clk;
  syscon.rst<=w_rst;

  cpu: entity work.xtc_top_sdram
  port map (
    wb_syscon   => syscon,
    -- Master wishbone interface
    iowbi           => wbo,
    iowbo           => wbi,
    nmi             => nmi,
    nmiack          => nmiack,
    dmawbi.dat      => (others => 'X'),
    dmawbi.adr      => (others => 'X'),
    dmawbi.tag      => (others => 'X'),
    dmawbi.cyc      => '0',
    dmawbi.bte      => BTE_BURST_LINEAR,
    dmawbi.cti      => CTI_CYCLE_CLASSIC,
    dmawbi.stb      => '0',
    dmawbi.we       => '0',
    dmawbi.sel      => "0000",
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

  DRAM_ADDR(12)<='0';

  sdram: entity work.mt48lc16m16a2
    GENERIC MAP  (
        addr_bits  => 13,
        data_bits  => 16,
        col_bits   => 8,
        index      => 0,
      	fname      => "sdram.srec"
    )
    PORT MAP (
        Dq    => DRAM_DQ,
        Addr  => DRAM_ADDR(12 downto 0),
        Ba    => DRAM_BA,
        Clk   => DRAM_CLK,
        Cke   => DRAM_CKE,
        Cs_n  => DRAM_CS_N,
        Ras_n => DRAM_RAS_N,
        Cas_n => DRAM_CAS_N,
        We_n  => DRAM_WE_N,
        Dqm   => DRAM_DQM
    );

  ioctrl: entity work.xtc_ioctrl
    port map (
      syscon      => syscon,
      wbi         => wbi,
      wbo         => wbo,
      swbi        => swbi,
      swbo        => swbo,
      sids        => sids
    );


  nodev0: entity work.nodev
    port map (
      syscon      => syscon,
      wbi         => swbo(0),
      wbo         => swbi(0)
  );

  myuart: entity work.uart
    port map (
      syscon      => syscon,
      wbi         => swbo(1),
      wbo         => swbi(1),

      tx          => open,
      rx          => 'X'
  );

  flashspi: entity work.spi
    generic map (
      INTERNAL_SPI => true
    )
    port map (
      syscon    => syscon,
      wbi       => swbo(2),
      wbo       => swbi(2),
      mosi      => mosi,
      miso      => miso,
      sck       => sck,
      cs        => sel
  );

  sdspi: entity work.spi
    generic map (
      INTERNAL_SPI => false
    )
    port map (
      syscon    => syscon,
      wbi       => swbo(3),
      wbo       => swbi(3),
      mosi      => open,
      miso      => '0',
      sck       => open,
      cs        => open
  );


  emptyslots: for N in 4 to 15 generate
    eslot: entity work.nodev
      port map (
        syscon    => syscon,
        wbi       => swbo(N),
        wbo       => swbi(N)
     );
  end generate;


  
  flash: entity work.M25P16
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
    wait;
  end process;

  -- Interrupt test
  --process
  --begin
  -- wbo.int <= '0';
  --  wait for 2060 ns;
  --  wbo.int <= '1';
  --  wait for 150 ns;
  --  wbo.int <= '0';
  --end process;

  -- NMI test
  --process
  --begin
  --  nmi<='0';
  --  wait for 8000 ns;
  --  wait until rising_edge(w_clk);
  --  nmi<='1';
  --  wait until nmiack='1';
  --  wait until rising_edge(w_clk);
  --  nmi<='0';
  --  wait for 10000 ns;
  --  nmi<='1';
  --  wait until nmiack='1';
  --  wait until rising_edge(w_clk);
  --  nmi<='0';
  --  wait;
  --end process;

end sim;
