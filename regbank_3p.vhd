library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.newcpupkg.all;
use work.newcpucomppkg.all;

entity regbank_3p is
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
    rb3_wr:   in std_logic_vector(31 downto 0);
    rb3_we:   in std_logic;
    rb3_en:   in std_logic
  );
end entity regbank_3p;

architecture behave of regbank_3p is

  component regbank_2p is
  generic (
    ADDRESS_BITS: integer := 4
  );
  port (
    clk:      in std_logic;

    rb1_addr: in std_logic_vector(ADDRESS_BITS-1 downto 0);
    rb1_en:   in std_logic;
    rb1_rd:   out std_logic_vector(31 downto 0);

    rb2_addr: in std_logic_vector(ADDRESS_BITS-1 downto 0);
    rb2_wr:   in std_logic_vector(31 downto 0);
    rb2_we:   in std_logic;
    rb2_en:   in std_logic
  );
  end component;

begin
  -- Register bank, three port

  rba: regbank_2p
  generic map (
    ADDRESS_BITS => ADDRESS_BITS
  )
  port map (
    clk       => clk,
    rb1_addr  => rb1_addr,
    rb1_en    => rb1_en,
    rb1_rd    => rb1_rd,

    rb2_addr  => rb3_addr,
    rb2_wr    => rb3_wr,
    rb2_we    => rb3_we,
    rb2_en    => rb3_en
  );

  rbb: regbank_2p
  generic map (
    ADDRESS_BITS => ADDRESS_BITS
  )
  port map (
    clk       => clk,
    rb1_addr  => rb2_addr,
    rb1_en    => rb2_en,
    rb1_rd    => rb2_rd,

    rb2_addr  => rb3_addr,
    rb2_wr    => rb3_wr,
    rb2_we    => rb3_we,
    rb2_en    => rb3_en
  );

end behave;
