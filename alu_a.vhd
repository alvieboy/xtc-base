library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.xtcpkg.all;

entity alu is
  port (
    clk: in std_logic;
    rst: in std_logic;

    a:  in unsigned(31 downto 0);
    b:  in unsigned(31 downto 0);
    o: out unsigned(31 downto 0);
    y: out unsigned(31 downto 0);
    op: in alu_op_type;
    en: in std_logic;

    ci: in std_logic;
    cen:  in std_logic; -- Carry enable

    busy: out std_logic;
    co: out std_logic;
    zero: out std_logic;
    ovf:   out std_logic;
    sign: out std_logic

  );
end entity;

architecture behave of alu is

  signal alu_a, alu_b, alu_r: unsigned(32 downto 0);
  signal alu_add_r, alu_sub_r: unsigned(32 downto 0);
  signal carryext: unsigned (32 downto 0);
  signal modify_flags: boolean;

  component mult is
  port (
    clk:  in std_logic;
    rst:  in std_logic;
    lhs:  in signed(31 downto 0);
    rhs:  in signed(31 downto 0);
    en:   in std_logic;
    m:    out signed(31 downto 0);
    y:    out signed(31 downto 0);
    valid: out std_logic; -- Multiplication valid
    comp:  out std_logic -- Computing
  );
  end component;

  component shifter is
  port (
    a:  in unsigned(31 downto 0);
    b:  in unsigned(4 downto 0);
    o:  out unsigned(31 downto 0);
    left: in std_logic;
    arith:in std_logic
  );
  end component;


  signal mult_en: std_logic;
  signal mult_a: signed(31 downto 0);
  signal mult_b: signed(31 downto 0);
  signal mult_r: signed(31 downto 0);
  signal mult_y: signed(31 downto 0);
  signal mult_busy: std_logic;
  signal mult_valid: std_logic;

  signal shift_arith: std_logic;
  signal shift_out: unsigned(31 downto 0);
  signal shift_left: std_logic;
begin

  mulen: if MULT_ENABLED generate

  multiplier: mult
  port map (
    clk   => clk,
    rst   => rst,
    lhs   => mult_a,
    rhs   => mult_b,
    en    => mult_en,
    m     => mult_r,
    y     => mult_y,
    valid => mult_valid,
    comp  => mult_busy
  );

  end generate;

  muldis: if not MULT_ENABLED generate

    mult_r <= (others => 'X');
    mult_y <= (others => 'X');
    mult_valid <= '0';
    mult_busy  <= '0';

  end generate;

  shifter_inst: shifter
    port map (
      a => alu_a(31 downto 0),
      b => alu_b(4 downto 0),
      o => shift_out,
      left => shift_left,
      arith => shift_arith
    );

  busy <= mult_busy;
  alu_a <= '0' & a;
  alu_b <= '0' & b;
  mult_a <= signed(a);
  mult_b <= signed(b);
  
  carryext(32 downto 1) <= (others => '0');
  carryext(0) <= ci when cen='1' else '0';--op=ALU_ADDC or op=ALU_SUBB else '0';

  alu_add_r <= alu_a + alu_b + carryext;
  alu_sub_r <= alu_a - alu_b - carryext;

  mult_en <= '1' when op=ALU_MUL and en='1' else '0';

  process(alu_add_r, carryext, alu_a, alu_b, alu_sub_r, op, mult_valid, mult_r,shift_out,mult_y)
  begin

    shift_left <= 'X';
    shift_arith <= 'X';

    case op is
      when ALU_ADD => -- | ALU_ADDRI |ALU_ADDC =>
        alu_r <= alu_add_r;

      when ALU_SUB => --| ALU_CMP | ALU_SUBB =>
        alu_r <= alu_sub_r;

      when ALU_AND  => alu_r <= alu_a and alu_b;
      when ALU_OR   => alu_r <= alu_a or alu_b;
      --when ALU_NOT  => alu_r <= not alu_a;
      when ALU_XOR  => alu_r <= alu_a xor alu_b;

      when ALU_SEXTB => alu_r(7 downto 0) <= alu_a(7 downto 0);
        alu_r(32 downto 8) <= (others => alu_a(7));

      when ALU_SEXTS => alu_r(15 downto 0) <= alu_a(15 downto 0);
        alu_r(32 downto 16) <= (others => alu_a(15));

      when ALU_SHL =>
        shift_arith<='X';
        shift_left<='1';
        alu_r <= 'X' & shift_out;
      when ALU_SRA =>
        shift_arith<='1';
        shift_left<='0';
        alu_r <= 'X' & shift_out;
      when ALU_SRL =>
        shift_arith<='0';
        shift_left<='0';
        alu_r <= 'X' & shift_out;

      when others => alu_r <= (others =>'X');

    end case;

    if mult_valid='1' then
      alu_r <= mult_y(31) & unsigned(mult_r);
    end if;

  end process;
  y <= unsigned(mult_y);
  co    <= alu_r(32);
  sign  <= alu_r(31);
  o     <= alu_r(31 downto 0);
  zero  <= '1' when alu_r(31 downto 0)=x"00000000" else '0';

end behave;
