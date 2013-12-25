library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.xtcpkg.all;

entity shifter is
  port (
    --clk: in std_logic;
    --rst: in std_logic;

    a:  in unsigned(31 downto 0);
    b:  in unsigned(4 downto 0);
    o:  out unsigned(31 downto 0);
    left: in std_logic;
    arith:in std_logic
  );
end entity shifter;


architecture behave of shifter is

  signal ina: unsigned(31 downto 0);

begin

  ina <= a;

  process(ina,b,left,arith)
    variable i: unsigned(63 downto 0);
    variable cnt: unsigned(4 downto 0);
  begin

    i := x"00000000" & ina;
    cnt := b;

    if left='1' then
      i(31 downto 0) := (others => '0');
      i(63 downto 31) := '0' & ina;
      cnt := not cnt;
    elsif arith='1' then
      if ina(31) = '1' then
        i(63 downto 32) := (others => '1');
      else
        i(63 downto 32) := (others => '0');
      end if;
    end if;

    -- Shift according to each bit.

    if cnt(4)='1' then
      i(47 downto 0) := i(63 downto 16);
    end if;
    if cnt(3)='1' then
      i(39 downto 0) := i(47 downto 8);
    end if;
    if cnt(2) = '1' then
      i(35 downto 0) := i(39 downto 4);
    end if;
    if cnt(1) = '1' then
      i(33 downto 0) := i(35 downto 2);
    end if;
    if cnt(0) = '1' then
      i(31 downto 0) := i(32 downto 1);
    end if;

    o <= i(31 downto 0);

  end process;

end behave;
