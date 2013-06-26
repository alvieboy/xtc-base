library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.newcpupkg.all;

entity fetch is
  port (
    clk:  in std_logic;
    rst:  in std_logic;

    -- Connection to ROM
    stall: in std_logic;
    valid: in std_logic;
    address: out std_logic_vector(31 downto 0);
    read:   in std_logic_vector(31 downto 0);
    enable: out std_logic;
    strobe: out std_logic;
    
    -- Outputs for next stages
    fuo:  out fetch_output_type
  );
end entity fetch;

architecture behave of fetch is
  signal fr: fetch_regs_type;
begin

  fuo.r <= fr;
  fuo.opcode <= read(15 downto 0);
  fuo.valid <= valid;

  process(fr, rst, clk, stall, valid)
    variable fw: fetch_regs_type;
  begin
    fw := fr;

    address <= std_logic_vector(fr.fpc);

    enable <= '1';
    strobe <= '1';

    if stall='0' then
      fw.fpc := fr.fpc + 4;
    end if;

    if valid='1' then
      fw.pc := fw.npc;
      fw.npc := fw.pc + 4;
    end if;

    if rst='1' then
      fw.pc := (others => '0');
      fw.npc := (others => '0');
      fw.npc(2) := '1';
      fw.fpc := (others => '0');
      strobe <= '0';
      enable <= '0';
    end if;

    if rising_edge(clk) then
      fr <= fw;
    end if;

  end process;

end behave;
