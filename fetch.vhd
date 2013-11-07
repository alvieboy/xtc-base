library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.xtcpkg.all;

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
    -- Control
    freeze:    in std_logic;
    jump:     in std_logic;
    jumpaddr: in word_type;
    -- Outputs for next stages
    fuo:  out fetch_output_type
  );
end entity fetch;

architecture behave of fetch is
  signal fr: fetch_regs_type;
begin

  fuo.r <= fr;
  fuo.opcode <= read(31 downto 0);

  process(fr, rst, clk, stall, valid, freeze, jump, jumpaddr)
    variable fw: fetch_regs_type;
    variable npc: word_type;
    variable realnpc: word_type;
  begin
    fw := fr;
    npc := fr.fpc + 4;
    realnpc := fr.pc + 4;

    address <= std_logic_vector(fr.fpc);
    fuo.valid <= valid;

    enable <= not freeze;
    strobe <= not freeze;

    case fr.state is
      when running =>
        if jump='0' then
          --and freeze='0'
          if stall='0' and freeze='0' then
            fw.fpc := npc;
          end if;
      
          if valid='1' then
            if freeze='0' then
              fw.pc := realnpc;
            end if;
            --fr.ipc;
            --end if;
            --fw.ipc := fr.fpc;
          end if;
        else
          -- Jump request
          fw.fpc := jumpaddr;
          fw.fpc(1 downto 0) := "00";

          fw.pc := jumpaddr;
          fw.pc(1 downto 0) := "00";

          fw.state := jumping;
          strobe <= '0';
          enable <= '0';
          --fuo.valid <= '0';

        end if;
      when jumping =>
        if stall='0' then
          fw.fpc := npc;
          strobe <= '1';
          enable <= '1';
          --fw.ipc := fr.fpc;
          --fw.pc := realnpc;
          fw.state := running;
        end if;
        fuo.valid<='0';
      when others =>
    end case;

    if rst='1' then
      fw.pc := (others => '0');
      --fw.ipc := (others => '0');
      fw.fpc := (others => '0');
      strobe <= '0';
      enable <= '0';
      fw.state := running;
    end if;

    if rising_edge(clk) then
      fr <= fw;
    end if;

  end process;

end behave;
