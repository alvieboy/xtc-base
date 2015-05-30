library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity mux1_16 is
  port (
    i: in std_logic_vector(15 downto 0);
    sel: in std_logic_vector(3 downto 0);
    o: out std_logic
  );
end entity mux1_16;

architecture behave of mux1_16 is

 signal sel_i: integer range 0 to 15;

begin

  sel_i <= conv_integer(sel);

  o <= i(sel_i);

end behave;