library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.newcpupkg.all;
use work.newcpucomppkg.all;

entity regbank_2p is
  port (
    clk:      in std_logic;

    rb1_addr: in std_logic_vector(2 downto 0);
    rb1_en:   in std_logic;
    rb1_rd:   out std_logic_vector(31 downto 0);

    rb2_addr: in std_logic_vector(2 downto 0);
    rb2_wr:   in std_logic_vector(31 downto 0);
    rb2_we:   in std_logic;
    rb2_en:   in std_logic
  );
end entity regbank_2p;

architecture behave of regbank_2p is

  signal rb1_we: std_logic;

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

  rb: generic_dp_ram
  generic map (
    address_bits  => 3,
    data_bits     => 32
  )
  port map (
    clka    => clk,
    ena     => rb1_en,
    wea     => rb1_we,
    addra   => rb1_addr,
    dia     => rb2_wr,
    doa     => rb1_rd,
    clkb    => clk,
    enb     => rb2_en,
    web     => rb2_we,
    addrb   => rb2_addr,
    dib     => rb2_wr,
    dob     => open
  );

end behave;
