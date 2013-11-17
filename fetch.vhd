library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.xtcpkg.all;
use work.xtccomppkg.all;

entity fetch is
  port (
    clk:   in std_logic;
    clk2x: in std_logic;
    rst:   in std_logic;

    -- Connection to ROM
    stall:    in std_logic;
    valid:    in std_logic;
    address:  out std_logic_vector(31 downto 0);
    read:     in std_logic_vector(31 downto 0);
    enable:   out std_logic;
    strobe:   out std_logic;
    -- Control
    freeze:    in std_logic;
    jump:     in std_logic;
    jumpaddr: in word_type;
    dual:     in std_logic;
    -- Outputs for next stages
    fuo:  out fetch_output_type
  );
end entity fetch;

architecture behave of fetch is

  signal fr: fetch_regs_type;
  signal data_push_enable: std_logic;
  signal queue_clear: std_logic;
  signal queue_full: std_logic;
  signal queue_pop:  std_logic;
  signal queue_dual_pop:  std_logic;
  signal queue_empty: std_logic;
  signal queue_dual_valid: std_logic;

  signal opcode0, opcode1: std_logic_vector(15 downto 0);

  signal fpc: unsigned(31 downto 0);

  signal clksync: std_logic;
  signal valid_q: std_logic;
  signal infetch: std_logic;

begin

 
  fuo.valid <= valid;


  fuo.r <= fr;

  fuo.opcode <= opcode0 & opcode1;

  address <= std_logic_vector(fr.fpc);


  process(fr, rst, clk, stall, valid, freeze, jump, jumpaddr, dual)
    variable fw: fetch_regs_type;
    variable npc: word_type;
    variable realnpc: word_type;
  begin
    fw := fr;
    npc := fr.fpc + 4;

    enable <= '1';
    strobe <= '1';

    if jump='0' then
      if valid_q='1' and freeze='0' then
        if dual='1' then
          fw.pc := fr.pc+4;
          fw.fpc := fr.pc + 4;
        else
          fw.pc := fr.pc+2;
          fw.fpc := fr.pc + 4;
        end if;

        fw.qopc := read(15 downto 0);


      end if;
    else
      fw.pc := unsigned(jumpaddr);
      fw.fpc := unsigned(jumpaddr) + 2;

    end if;


    if rst='1' then
      fw.pc := (others => '0');
    end if;

    if rising_edge(clk) then
      fr <= fw;
    end if;

  end process;

end behave;
