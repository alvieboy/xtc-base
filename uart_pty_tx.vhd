library IEEE;
use IEEE.std_logic_1164.all;
use work.pty.all;
use ieee.std_logic_arith.all;
use IEEE.numeric_std.all;

entity uart_pty_tx is
   port(
      clk:    in  std_logic;
      rst:    in  std_logic;  
      tx:     out std_logic
   );
end entity uart_pty_tx;

architecture sim of uart_pty_tx is

  component TxUnit is
  port (
     clk_i    : in  std_logic;  -- Clock signal
     reset_i  : in  std_logic;  -- Reset input
     enable_i : in  std_logic;  -- Enable input
     load_i   : in  std_logic;  -- Load input
     txd_o    : out std_logic;  -- RS-232 data output
     busy_o   : out std_logic;  -- Tx Busy
     datai_i  : in  std_logic_vector(7 downto 0)); -- Byte to transmit
  end component TxUnit;

  component uart_brgen is
  port (
     clk:     in std_logic;
     rst:     in std_logic;
     en:      in std_logic;
     count:   in std_logic_vector(15 downto 0);
     clkout:  out std_logic
     );
  end component uart_brgen;

  signal rxclk,txclk: std_logic;

  signal load_data: std_logic;
  signal busy: std_logic;
  signal data: std_logic_vector(7 downto 0);
begin

  rxclkgen: uart_brgen
    port map (
      clk => clk,
      rst => rst,
      en => '1',
      count => x"0005",  -- 1Mbps
      clkout => rxclk
    );

  txclkgen: uart_brgen
    port map (
      clk => clk,
      rst => rst,
      en => rxclk,
      count => x"000f",
      clkout => txclk
    );


  txu: TxUnit
    port map (
      clk_i    => clk,
      reset_i  => rst,
      enable_i => txclk,
      load_i   => load_data,

      txd_o    => tx,
      busy_o   => busy,
      datai_i  => data
    );

  process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        load_data<='1';
      else
        load_data<='0';
        if busy='0' then
          if pty_available > 0 then
            data <= conv_std_logic_vector(pty_receive,8);
            load_data<='1';
          end if;
        end if;
      end if;
    end if;
  end process;

   process
  variable c: integer;
  begin
    c := pty_initialize;
    wait;
  end process;

end sim;

