library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.xtcpkg.all;
use work.xtccomppkg.all;

entity regbank_2p is
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
end entity regbank_2p;

architecture behave of regbank_2p is

  constant NUMADDRESSES: integer := 2 ** ADDRESS_BITS;

  signal rb1_we: std_logic;
  signal ssra, ssrb: std_logic;
  constant srval: std_logic_vector(31 downto 0)  := (others => '0');
  constant addrzero: std_logic_vector(ADDRESS_BITS-1 downto 0):= (others => '0');
begin
  -- Register bank.

  -- Note the hack for writing to 1st port when 2nd port is
  -- being written to same address

  process(rb1_addr,rb2_addr,rb2_we)
  begin
    rb1_we<='0';
    if rb2_we='1' and rb1_addr=rb2_addr then
      rb1_we<='1';
    end if;
  end process;

  ssra<='1' when rb1_addr=addrzero else '0';
  ssrb<='1' when rb2_addr=addrzero else '0';

  rb: generic_dp_ram_r
  generic map (
    address_bits  => ADDRESS_BITS,
    srval_1 => srval,
    srval_2 => srval
  )
  port map (
    clka    => clk,
    ena     => rb1_en,
    wea     => rb1_we,
    ssra    => ssra,
    addra   => rb1_addr,
    dia     => rb2_wr,
    doa     => rb1_rd,
    clkb    => clk,
    enb     => rb2_en,
    ssrb    => ssrb,
    web     => rb2_we,
    addrb   => rb2_addr,
    dib     => rb2_wr,
    dob     => open
  );

end behave;
