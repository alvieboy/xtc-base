--
--  UART for Newcpu
-- 
--  Copyright 2010 Alvaro Lopes <alvieboy@alvie.com>
-- 
--  Version: 1.0
-- 
--  The FreeBSD license
--  
--  Redistribution and use in source and binary forms, with or without
--  modification, are permitted provided that the following conditions
--  are met:
--  
--  1. Redistributions of source code must retain the above copyright
--     notice, this list of conditions and the following disclaimer.
--  2. Redistributions in binary form must reproduce the above
--     copyright notice, this list of conditions and the following
--     disclaimer in the documentation and/or other materials
--     provided with the distribution.
--  
--  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY
--  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
--  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
--  PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
--  ZPU PROJECT OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
--  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
--  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
--  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
--  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
--  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
--  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
--  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--  
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.wishbonepkg.all;

entity uart is
  generic (
    bits: integer := 11
  );
  port (
    syscon:     in wb_syscon_type;
    wbi:        in wb_mosi_type;
    wbo:        out wb_miso_type;

    tx:         out std_logic;
    rx:         in std_logic
  );
end entity uart;

architecture behave of uart is

  component uart_rx is
  port (
    clk:      in std_logic;
	 	rst:      in std_logic;
    rx:       in std_logic;
    rxclk:    in std_logic;
    read:     in std_logic;
    data:     out std_logic_vector(7 downto 0);
    data_av:  out std_logic
  );
  end component uart_rx;


  component TxUnit is
  port (
     clk_i    : in  std_logic;  -- Clock signal
     reset_i  : in  std_logic;  -- Reset input
     enable_i : in  std_logic;  -- Enable input
     load_i   : in  std_logic;  -- Load input
     txd_o    : out std_logic;  -- RS-232 data output
     busy_o   : out std_logic;  -- Tx Busy
     intx_o   : out std_logic;  -- Tx in progress
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

  component fifo is
  generic (
    bits: integer := 11
  );
  port (
    clk:      in std_logic;
    rst:      in std_logic;
    wr:       in std_logic;
    rd:       in std_logic;
    write:    in std_logic_vector(7 downto 0);
    read :    out std_logic_vector(7 downto 0);
    full:     out std_logic;
    empty:    out std_logic
  );
  end component fifo;


  signal uart_read: std_logic;
  signal uart_write: std_logic;
  signal divider_tx: std_logic_vector(15 downto 0) := x"000f";

  signal divider_rx_q: std_logic_vector(15 downto 0);

  signal data_ready: std_logic;
  signal received_data: std_logic_vector(7 downto 0);
  signal fifo_data: std_logic_vector(7 downto 0);
  signal uart_busy: std_logic;
  signal uart_intx: std_logic;
  signal fifo_empty: std_logic;
  signal rx_br: std_logic;
  signal tx_br: std_logic;
  signal rx_en: std_logic;

  signal dready_q: std_logic;
  signal data_ready_dly_q: std_logic;
  signal fifo_rd: std_logic;
  signal enabled_q: std_logic;
  signal do_interrupt: std_logic;
  signal int_enabled: std_logic;
  signal ack: std_logic;
  signal tsc: unsigned(31 downto 0);

begin

  --enabled <= enabled_q;
  wbo.int<= do_interrupt;
  wbo.ack <= ack;
  
  rx_inst: uart_rx
    port map(
      clk     => syscon.clk,
      rst     => syscon.rst,
      rxclk   => rx_br,
      read    => uart_read,
      rx      => rx,
      data_av => data_ready,
      data    => received_data
   );

  uart_read <= dready_q;

  tx_core: TxUnit
    port map(
      clk_i     => syscon.clk,
      reset_i   => syscon.rst,
      enable_i  => tx_br,
      load_i    => uart_write,
      txd_o     => tx,
      busy_o    => uart_busy,
      intx_o    => uart_intx,
      datai_i   => wbi.dat(7 downto 0)
    );

  -- TODO: check multiple writes

   -- Rx timing
  rx_timer: uart_brgen
    port map(
      clk => syscon.clk,
      rst => syscon.rst,
      en => '1',
      clkout => rx_br,
      count => divider_rx_q
    );

   -- Tx timing
  tx_timer: uart_brgen
    port map(
      clk => syscon.clk,
      rst => syscon.rst,
      en => rx_br,
      clkout => tx_br,
      count => divider_tx
    );

  process(syscon.clk)
  begin
    if rising_edge(syscon.clk) then
      if syscon.rst='1' then
        dready_q<='0';
        data_ready_dly_q<='0';
      else

        data_ready_dly_q<=data_ready;

        if data_ready='1' and data_ready_dly_q='0' then
          dready_q<='1';
        else
          dready_q<='0';
        end if;

      end if;
    end if;
  end process;

  fifo_instance: fifo
    generic map (
      bits => bits
    )
    port map (
      clk   => syscon.clk,
      rst   => syscon.rst,
      wr    => dready_q,
      rd    => fifo_rd,
      write => received_data,
      read  => fifo_data,
      full  => open,
      empty => fifo_empty
    );
  

  fifo_rd<='1' when wbi.adr(3 downto 2)="00" and (wbi.cyc='1' and wbi.stb='1' and wbi.we='0') else '0';

  process(syscon.clk)--wb_adr_i, received_data, uart_busy, data_ready, fifo_empty, fifo_data,uart_intx, int_enabled)
  begin
    if rising_edge(syscon.clk) then
    case wbi.adr(3 downto 2) is
      when "01" =>
        wbo.dat <= (others => '0');
        wbo.dat(0) <= not fifo_empty;
        wbo.dat(1) <= uart_busy;
        wbo.dat(2) <= uart_intx;
        wbo.dat(3) <= int_enabled;
      when "00" =>
        wbo.dat <= (others => '0');
        wbo.dat(7 downto 0) <= fifo_data;
      when "11" =>
        wbo.dat <= std_logic_vector(tsc);
      when others =>
        wbo.dat <= (others => 'X');
    end case;
    end if;
  end process;

  process(syscon.clk)
  begin
    if rising_edge(syscon.clk) then
      if syscon.rst='1' then
        enabled_q<='0';
        int_enabled <= '0';
        do_interrupt<='0';
        ack<='0';
        tsc <= (others => '0');
      else
        tsc <= tsc + 1;
        ack <='0';
        uart_write<='0';

        if wbi.cyc='1' and wbi.stb='1' and ack='0' then
          ack <= '1';
          if wbi.we='1' then

          case wbi.adr(3 downto 2) is
            when "00" =>
              uart_write <= '1';
            when "01" =>
              divider_rx_q <= wbi.dat(15 downto 0);
              enabled_q  <= wbi.dat(16);
            when "10" =>
              int_enabled <= wbi.dat(0);
              do_interrupt <= '0';
            when others =>
              null;
          end case;
          end if;
        else
          if int_enabled='1' and fifo_empty='0' then
            do_interrupt <= '1';
            int_enabled <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

end behave;
