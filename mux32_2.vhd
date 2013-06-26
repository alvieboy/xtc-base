library ieee;
use ieee.std_logic_1164.all;

entity mux32_2 is
  port (
    i0: in std_logic_vector(31 downto 0);
    i1: in std_logic_vector(31 downto 0);
    sel: in std_logic;
    o: out std_logic_vector(31 downto 0)
  );
end entity mux32_2;

architecture behave of mux32_2 is
begin
  process(i0,i1,sel)
  begin
    case sel is
      when '0' => o <= i0;
      when '1' => o <= i1;
      when others => o <= (others => 'X');
    end case;
  end process;
end behave;
