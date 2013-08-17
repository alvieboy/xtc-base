library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.newcpupkg.all;

entity alu_A is
  port (
    clk: in std_logic;
    rst: in std_logic;

    a:  in unsigned(31 downto 0);
    b:  in unsigned(31 downto 0);
    o: out unsigned(31 downto 0);

    op: in alu1_op_type;

    ci: in std_logic;
    busy: out std_logic;
    co: out std_logic;
    zero: out std_logic;
    bo:   out std_logic;
    sign: out std_logic

  );
end entity;

architecture behave of alu_A is

  signal alu_a, alu_b, alu_r: unsigned(32 downto 0);
  signal alu_add_r, alu_sub_r: unsigned(32 downto 0);
  signal carryext: unsigned (32 downto 0);
  signal modify_flags: boolean;

begin

  busy <= '0';
  alu_a <= '0'&a;
  alu_b <= '0'&b;
  carryext(32 downto 1) <= (others => '0');
  carryext(0) <= ci;

  alu_add_r <= alu_a + alu_b;
  alu_sub_r <= alu_a - alu_b;

  process(alu_add_r, carryext, alu_a, alu_b, alu_sub_r, op)
  begin

    case op is
      when ALU1_ADD => alu_r <= alu_add_r;
      when ALU1_ADDC => alu_r <= alu_add_r + carryext;
      when ALU1_AND => alu_r <= alu_a and alu_b;
      when ALU1_OR => alu_r <= alu_a or alu_b;
      when ALU1_SUB => alu_r <= alu_sub_r;
      when ALU1_COPY_A => alu_r <= alu_a;
      when others => alu_r <= (others =>'X');
    end case;

  end process;

  co <= alu_add_r(32);
  sign <= alu_r(31);
  bo <= alu_sub_r(32);
  o <= alu_r(31 downto 0);
  zero <= '1' when alu_r(31 downto 0)=x"00000000" else '0';

end behave;