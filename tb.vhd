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

  nodev2: nodev port map ( syscon => syscon, wbi => swbo(2), wbo => swbi(2) );
  nodev3: nodev port map ( syscon => syscon, wbi => swbo(3), wbo => swbi(3) );
  nodev4: nodev port map ( syscon => syscon, wbi => swbo(4), wbo => swbi(4) );
  nodev5: nodev port map ( syscon => syscon, wbi => swbo(5), wbo => swbi(5) );
  nodev6: nodev port map ( syscon => syscon, wbi => swbo(6), wbo => swbi(6) );
  nodev7: nodev port map ( syscon => syscon, wbi => swbo(7), wbo => swbi(7) );
  nodev8: nodev port map ( syscon => syscon, wbi => swbo(8), wbo => swbi(8) );
  nodev9: nodev port map ( syscon => syscon, wbi => swbo(9), wbo => swbi(9) );
  nodev10: nodev port map ( syscon => syscon, wbi => swbo(10), wbo => swbi(10) );
  nodev11: nodev port map ( syscon => syscon, wbi => swbo(11), wbo => swbi(11) );
  nodev12: nodev port map ( syscon => syscon, wbi => swbo(12), wbo => swbi(12) );
  nodev13: nodev port map ( syscon => syscon, wbi => swbo(13), wbo => swbi(13) );
  nodev14: nodev port map ( syscon => syscon, wbi => swbo(14), wbo => swbi(14) );
  nodev15: nodev port map ( syscon => syscon, wbi => swbo(15), wbo => swbi(15) );


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
