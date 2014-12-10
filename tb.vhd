library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.xtcpkg.all;
use work.xtccomppkg.all;
use work.wishbonepkg.all;

entity tb is
end entity tb;

architecture sim of tb is

  constant period: time := 10 ns;--9.615 ns;
  signal w_clk: std_logic := '0';
  signal w_clk_2x: std_logic := '1';
  signal w_rst: std_logic := '0';

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

  component spi is
  generic (
    INTERNAL_SPI: boolean := false
  );
  port (
    syscon:     in wb_syscon_type;
    wbi:        in wb_mosi_type;
    wbo:        out wb_miso_type;
    mosi:     out std_logic;
    miso:     in std_logic;
    sck:      out std_logic;
    cs:       out std_logic;
    enabled:  out std_logic
  );
  end component spi;

  signal txd, rxd: std_logic;

  signal wbi: wb_mosi_type;
  signal wbo: wb_miso_type;
  signal syscon: wb_syscon_type;
  signal swbi: slot_wbi;
  signal swbo: slot_wbo;
  signal sids: slot_ids;

begin

  rxd <= '1';

  w_clk <= not w_clk after period/2;

  syscon.clk<=w_clk;
  syscon.rst<=w_rst;

  cpu: xtc_top_bram
  port map (
    wb_syscon       => syscon,
    -- Master wishbone interface
    iowbi           => wbo,
    iowbo           => wbi
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

  nodev0: nodev port map ( syscon => syscon, wbi => swbo(0), wbo => swbi(0) );

  myuart: uart
    port map (
      syscon    => syscon,
      wbi         => swbo(1),
      wbo         => swbi(1),
      tx        => txd,
      rx        => rxd
  );

  flashspi: spi
    generic map (
      INTERNAL_SPI => true
    )
    port map (
      syscon    => syscon,
      wbi       => swbo(2),
      wbo       => swbi(2),
      mosi      => open,
      miso      => '1',
      sck       => open,
      cs        => open
  );


  emptyslots: for N in 3 to 15 generate
    eslot: nodev
      port map (
        syscon    => syscon,
        wbi       => swbo(N),
        wbo       => swbi(N)
     );
  end generate;


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

end sim;
