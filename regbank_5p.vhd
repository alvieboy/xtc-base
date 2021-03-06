library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.xtcpkg.all;
use work.xtccomppkg.all;

entity regbank_5p is
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

    rbw_addr: in std_logic_vector(ADDRESS_BITS-1 downto 0);
    rbw_wr:   in std_logic_vector(31 downto 0);
    rbw_we:   in std_logic;
    rbw_en:   in std_logic;

    -- RTL Debug access
    dbg_addr:         in std_logic_vector(address_bits-1 downto 0) := (others => '0');
    dbg_do:           out std_logic_vector(32-1 downto 0)
  );
end entity regbank_5p;

architecture behave of regbank_5p is

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
    rb2_en:   in std_logic;
        -- RTL Debug access
    dbg_addr:         in std_logic_vector(address_bits-1 downto 0) := (others => '0');
    dbg_do:           out std_logic_vector(32-1 downto 0)

  );
  end component;

begin

  rba: regbank_2p
  generic map (
    ADDRESS_BITS => ADDRESS_BITS
  )
  port map (
    clk       => clk,
    rb1_addr  => rb1_addr,
    rb1_en    => rb1_en,
    rb1_rd    => rb1_rd,

    rb2_addr  => rbw_addr,
    rb2_wr    => rbw_wr,
    rb2_we    => rbw_we,
    rb2_en    => rbw_en,
    dbg_addr  => dbg_addr,
    dbg_do  => dbg_do
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

    rb2_addr  => rbw_addr,
    rb2_wr    => rbw_wr,
    rb2_we    => rbw_we,
    rb2_en    => rbw_en
  );

  rbc: regbank_2p
  generic map (
    ADDRESS_BITS => ADDRESS_BITS
  )
  port map (
    clk       => clk,
    rb1_addr  => rb3_addr,
    rb1_en    => rb3_en,
    rb1_rd    => rb3_rd,

    rb2_addr  => rbw_addr,
    rb2_wr    => rbw_wr,
    rb2_we    => rbw_we,
    rb2_en    => rbw_en
  );

  rbd: regbank_2p
  generic map (
    ADDRESS_BITS => ADDRESS_BITS
  )
  port map (
    clk       => clk,
    rb1_addr  => rb4_addr,
    rb1_en    => rb4_en,
    rb1_rd    => rb4_rd,

    rb2_addr  => rbw_addr,
    rb2_wr    => rbw_wr,
    rb2_we    => rbw_we,
    rb2_en    => rbw_en
  );

end behave;
