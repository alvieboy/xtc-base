library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.xtcpkg.all;

entity alu_B is
  port (
    clk: in std_logic;
    rst: in std_logic;

    a:  in unsigned(31 downto 0);
    b:  in unsigned(31 downto 0);
    o: out unsigned(31 downto 0);

    op: in alu2_op_type;

    co: out std_logic;
    zero: out std_logic;
    bo:   out std_logic;
    sign: out std_logic
  );
end entity;

architecture behave of alu_B is

  component shifter is
  port (
    a:  in unsigned(31 downto 0);
    b:  in unsigned(4 downto 0);
    o:  out unsigned(31 downto 0);
    left: in std_logic;
    arith:in std_logic
  );
  end component shifter;

  signal r: unsigned(32 downto 0);

  signal shift_a: unsigned(31 downto 0);
  signal shift_b: unsigned(4 downto 0);
  signal shift_o: unsigned(31 downto 0);
  signal shift_left: std_logic;
  signal shift_arith: std_logic;

begin

  o<=r(31 downto 0);
  shift_a <= a;
  shift_b <= b(4 downto 0);

shft: shifter
    port map (
      a => shift_a,
      b => shift_b,
      o => shift_o,
      left => shift_left,
      arith => shift_arith
    );

  

  process(a, b, op, shift_o)
    variable delta: unsigned(31 downto 0);
  begin
    shift_left <= 'X';
    shift_arith <= 'X';

    case op is
      when ALU2_ADD =>
        r <= (a(31)&a) + (b(31)&b);

      when ALU2_CMPI =>
        r <= (a(31)&a) - (b(31)&b);

      when ALU2_SRA =>
        r(31 downto 0) <= shift_o;
        r(32) <= '0';
        shift_left<='0';
        shift_arith<='1';

      when ALU2_SRL =>
        r(31 downto 0) <= shift_o;
        r(32) <= '0';
        shift_left<='0';
        shift_arith<='0';

      when ALU2_SHL =>
        r(31 downto 0) <= shift_o;
        r(32) <= '0';
        shift_left<='1';

      when ALU2_SEXTB =>
        r(7 downto 0) <= a(7 downto 0);
        r(32 downto 8) <= (others => a(7));

      when ALU2_SEXTS =>
        r(15 downto 0) <= a(15 downto 0);
        r(32 downto 16) <= (others => a(15));

      when ALU2_NOT =>
        r(31 downto 0) <= not a;
        r(32) <= '0';


      when others => r <= (others =>'X');
    end case;

  end process;

  co    <= r(32);
  sign  <= r(31);
  bo    <= r(32);
  zero  <= '1' when r(31 downto 0)=x"00000000" else '0';

end behave;
