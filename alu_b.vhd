library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.newcpupkg.all;

entity alu_B is
  port (
    clk: in std_logic;
    rst: in std_logic;

    a:  in unsigned(31 downto 0);
    b:  in unsigned(31 downto 0);
    o: out unsigned(31 downto 0);

    op: in alu2_op_type
  );
end entity;

architecture behave of alu_B is

  signal r: unsigned(31 downto 0);

begin

  o<=r;

  process(a, b, op)
    variable delta: unsigned(31 downto 0);
  begin
    case op is
      when ALU2_IMMFIRST =>
        r(31 downto 11) <= (others => b(10));
        r(10 downto 0) <= unsigned(b(10 downto 0));
      when ALU2_IMMNEXT =>
        r(31 downto 11) <= a(20 downto 0);
        r(10 downto 0) <= unsigned(b(10 downto 0));
      when ALU2_NOT =>
        r <= not a;
      when ALU2_COPY =>
        r <= a;
      when ALU2_SADD =>
        case b(8 downto 6) is
          when "000" => delta := x"00000000";
          when "001" => delta := x"00000001";
          when "010" => delta := x"00000002";
          when "011" => delta := x"00000004";
          when "111" => delta := x"FFFFFFFF";
          when "110" => delta := x"FFFFFFFE";
          when "101" => delta := x"FFFFFFFC";
          when "100" => delta := (others => DontCareValue);--x"00000000";
          when others => null;
        end case;
        r <= a + delta;
      -- Special load instructions.

      when others => r <= (others =>'X');
    end case;

  end process;

end behave;
