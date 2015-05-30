library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.wishbonepkg.all;

entity nodev is
  port (
    syscon:     in wb_syscon_type;
    wbi:        in wb_mosi_type;
    wbo:        out wb_miso_type
  );
end entity nodev;
architecture behave of nodev is
  signal ack,err: std_logic := '0';
begin
  wbo.ack<=ack;
  wbo.err<=err;
  wbo.dat<=(others => 'X');
  process(syscon.clk)
  begin
    if rising_edge(syscon.clk) then
      if syscon.rst='1' then
        ack<='0';
        err<='0';
      else
        ack<='0';
        err<='0';
        if err='0' and wbi.stb='1' and wbi.cyc='1' then
          --ack<='1';
          err<='1';
        end if;
      end if;
    end if;
  end process;
end behave;

