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
    read:     in std_logic_vector(15 downto 0);
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

  queue: insnqueue
  port map (
    rst       => rst,
    clkw      => clk2x,
    din       => read,
    en        => data_push_enable,
    clr       => queue_clear,
    full      => queue_full,

    clkr      => clk,
    pop       => queue_pop,
    dualpop   => queue_dual_pop,
    dout0     => opcode0,
    dout1     => opcode1,
    empty     => queue_empty,
    dvalid    => queue_dual_valid
  );

  process(clk)
  begin
    if rising_edge(clk2x) then
      if rst='1' then
        clksync<='1';
      else
        clksync<=not clksync;
      end if;

      if queue_clear='1' then
        valid_q <= '0';
      else
        if clksync='1' then
          valid_q <= queue_dual_valid;--not queue_empty;
        end if;
      end if;
    end if;
  end process;

  fuo.valid <= valid_q;


  fuo.r <= fr;
  fuo.opcode <= opcode0 & opcode1;--read(31 downto 0);

  data_push_enable <= valid and not queue_full and not queue_clear;

  queue_dual_pop<=dual;
  queue_pop <= not freeze and not queue_empty and valid_q and not jump;

  address <= std_logic_vector(fpc);

--  queue_clear <= jump and clksync;

  process(clk2x)
  begin
    if rising_edge(clk2x) then
      if rst='1' then
        fpc <= (others => '0');
      else
        if infetch='0' then
          queue_clear <= '0';
        else
          infetch <='0';
        end if;
        if queue_full='0' and stall='0' then
          fpc <= fpc + 2;
        end if;

        if clksync='1' and jump='1' then
          fpc <= jumpaddr(31 downto 0);
          queue_clear <= '1';
          infetch<='1';
        end if;

      end if;
    end if;
  end process;

  enable <= not queue_full;
  strobe <= '1';

  process(fr, rst, clk, stall, valid, freeze, jump, jumpaddr, dual)
    variable fw: fetch_regs_type;
    variable npc: word_type;
    variable realnpc: word_type;
  begin
    fw := fr;

    if jump='0' then
      if valid_q='1' and freeze='0' then
        if dual='1' then
          fw.pc := fr.pc+4;
          fw.fpc := fr.pc + 6;
        else
          fw.pc := fr.pc+2;
          fw.fpc := fr.pc + 4;
        end if;
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
