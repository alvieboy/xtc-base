library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
library work;
use work.wishbonepkg.all;

entity wb_master_p_to_slave_np is
  port (
    syscon:   in wb_syscon_type;

    -- Master signals
    mwbi:     in wb_mosi_type;
    mwbo:     out wb_miso_type;
    -- Slave signals
    swbi:     in wb_miso_type;
    swbo:     out wb_mosi_type
  );
end entity wb_master_p_to_slave_np;

architecture behave of wb_master_p_to_slave_np is

type state_type is ( idle, wait_for_ack );

signal state: state_type;
signal wo: wb_mosi_type;

begin

process(syscon.clk)
begin
  if rising_edge(syscon.clk) then
    if syscon.rst='1' then
      state <= idle;
      mwbo.stall <= '0';
      wo.cyc<='0';
    else
      case state is
        when idle =>
          if mwbi.cyc='1' and mwbi.stb='1' then
            state <= wait_for_ack;
            wo <= mwbi;
            mwbo.stall <= '1';
          end if;
        when wait_for_ack =>
          if swbi.ack='1' then
            wo.cyc <= '0';
            wo.stb <= '0';
            mwbo.stall <= '0';

            state <= idle;
          end if;
        when others =>
      end case;
    end if;
  end if;
end process;


swbo.stb <= wo.stb;-- when state=idle else '1';

swbo.dat <= wo.dat;
swbo.adr <= wo.adr;
swbo.sel <= wo.sel;
swbo.tag <= wo.tag;
swbo.we  <= wo.we;
swbo.cyc <= wo.cyc;

mwbo.dat <= swbi.dat;
mwbo.ack <= swbi.ack;
mwbo.tag <= swbi.tag;


end behave;
