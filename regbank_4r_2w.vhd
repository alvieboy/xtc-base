library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
library work;
use work.newcpupkg.all;
use work.newcpucomppkg.all;

entity regbank_4r_2w is
  generic (
    ADDRESS_BITS: integer := 4
  );
  port (
    clk:      in std_logic;

    rb1_addr: in std_logic_vector(ADDRESS_BITS-1 downto 0);
    rb1_en:   in std_logic;
    rb1_rd:   out std_logic_vector(31 downto 0);

    rb2_addr: in std_logic_vector(ADDRESS_BITS-1 downto 0);
    rb2_en:   in std_logic;
    rb2_rd:   out std_logic_vector(31 downto 0);

    rb3_addr: in std_logic_vector(ADDRESS_BITS-1 downto 0);
    rb3_en:   in std_logic;
    rb3_rd:   out std_logic_vector(31 downto 0);

    rb4_addr: in std_logic_vector(ADDRESS_BITS-1 downto 0);
    rb4_en:   in std_logic;
    rb4_rd:   out std_logic_vector(31 downto 0);

    rbw1_addr: in std_logic_vector(ADDRESS_BITS-1 downto 0);
    rbw1_wr:   in std_logic_vector(31 downto 0);
    rbw1_we:   in std_logic;
    rbw1_en:   in std_logic;

    rbw2_addr: in std_logic_vector(ADDRESS_BITS-1 downto 0);
    rbw2_wr:   in std_logic_vector(31 downto 0);
    rbw2_we:   in std_logic;
    rbw2_en:   in std_logic
  );
end entity regbank_4r_2w;

architecture behave of regbank_4r_2w is

  component mux1_8 is
  port (
    i: in std_logic_vector(7 downto 0);
    sel: in std_logic_vector(2 downto 0);
    o: out std_logic
  );
  end component mux1_8;

  component regbank_5p is
  port (
    clk:      in std_logic;

    rb1_addr: in std_logic_vector(2 downto 0);
    rb1_en:   in std_logic;
    rb1_rd:   out std_logic_vector(31 downto 0);

    rb2_addr: in std_logic_vector(2 downto 0);
    rb2_en:   in std_logic;
    rb2_rd:   out std_logic_vector(31 downto 0);

    rb3_addr: in std_logic_vector(2 downto 0);
    rb3_en:   in std_logic;
    rb3_rd:   out std_logic_vector(31 downto 0);

    rb4_addr: in std_logic_vector(2 downto 0);
    rb4_en:   in std_logic;
    rb4_rd:   out std_logic_vector(31 downto 0);

    rbw_addr: in std_logic_vector(2 downto 0);
    rbw_wr:   in std_logic_vector(31 downto 0);
    rbw_we:   in std_logic;
    rbw_en:   in std_logic
  );
  end component regbank_5p;

  --type sbtype is array(0 to 7) of std_logic;

  --shared variable scoreboard: sbtype := (others => '0');

  signal scoreboard: std_logic_vector(7 downto 0);

  signal src1,src2,src3,src4: std_logic;
  signal src1_sel,src2_sel,src3_sel,src4_sel: std_logic;
  signal w1,w2: std_logic;

  signal b1_rd_1, b1_rd_2, b1_rd_3, b1_rd_4: std_logic_vector(31 downto 0);
  signal b2_rd_1, b2_rd_2, b2_rd_3, b2_rd_4: std_logic_vector(31 downto 0);

  signal same_address: boolean;

begin

  -- Write ports
  w1 <= rbw1_en and rbw1_we;
  w2 <= rbw2_en and rbw2_we;

  m1: mux1_8 port map ( i => scoreboard, sel => rb1_addr, o => src1_sel );
  m2: mux1_8 port map ( i => scoreboard, sel => rb2_addr, o => src2_sel );
  m3: mux1_8 port map ( i => scoreboard, sel => rb3_addr, o => src3_sel );
  m4: mux1_8 port map ( i => scoreboard, sel => rb4_addr, o => src4_sel );


  same_address<=true when rbw1_addr=rb2_addr else false;

  process(clk)
  begin
    if rising_edge(clk) then

      if w1='1' and w2='0' then
        scoreboard( conv_integer(rbw1_addr) ) <= '0';
      elsif w1='0' and w2='1' then
        scoreboard( conv_integer(rbw2_addr) ) <= '1';
      elsif w1='1' and w2='1' then
        if same_address then
          scoreboard( conv_integer(rbw1_addr) ) <= 'X';
        else
          scoreboard( conv_integer(rbw1_addr) ) <= '0';
          scoreboard( conv_integer(rbw2_addr) ) <= '1';
        end if;
      else
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if rb1_en='1' then
        src1 <= src1_sel;
      end if;

      if rb2_en='1' then
        src2 <= src2_sel;
      end if;

      if rb3_en='1' then
        src3 <= src3_sel;
      end if;

      if rb4_en='1' then
        src4 <= src4_sel;
      end if;
    end if;
  end process;

  -- Register banks

  rb1: regbank_5p
  generic map (
    ADDRESS_BITS => ADDRESS_BITS
  )
  port map (
    clk       => clk,
    rb1_addr  => rb1_addr,
    rb1_en    => rb1_en,
    rb1_rd    => b1_rd_1,

    rb2_addr  => rb2_addr,
    rb2_en    => rb2_en,
    rb2_rd    => b1_rd_2,

    rb3_addr  => rb3_addr,
    rb3_en    => rb3_en,
    rb3_rd    => b1_rd_3,

    rb4_addr  => rb4_addr,
    rb4_en    => rb4_en,
    rb4_rd    => b1_rd_4,

    rbw_addr  => rbw1_addr,
    rbw_wr    => rbw1_wr,
    rbw_we    => rbw1_we,
    rbw_en    => rbw1_en
  );

  rb2: regbank_5p
  generic map (
    ADDRESS_BITS => ADDRESS_BITS
  )
  port map (
    clk       => clk,
    rb1_addr  => rb1_addr,
    rb1_en    => rb1_en,
    rb1_rd    => b2_rd_1,

    rb2_addr  => rb2_addr,
    rb2_en    => rb2_en,
    rb2_rd    => b2_rd_2,

    rb3_addr  => rb3_addr,
    rb3_en    => rb3_en,
    rb3_rd    => b2_rd_3,

    rb4_addr  => rb4_addr,
    rb4_en    => rb4_en,
    rb4_rd    => b2_rd_4,

    rbw_addr  => rbw2_addr,
    rbw_wr    => rbw2_wr,
    rbw_we    => rbw2_we,
    rbw_en    => rbw2_en
  );




  -- Selectors

  rb1_rd <= b1_rd_1 when src1='0' else b2_rd_1;
  rb2_rd <= b1_rd_2 when src2='0' else b2_rd_2;
  rb3_rd <= b1_rd_3 when src3='0' else b2_rd_3;
  rb4_rd <= b1_rd_4 when src4='0' else b2_rd_4;



end behave;
