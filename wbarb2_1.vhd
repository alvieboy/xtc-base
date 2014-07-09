library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
library work;
use work.wishbonepkg.all;

entity wbarb2_1 is
  generic (
    ADDRESS_HIGH: integer := 31;
    ADDRESS_LOW: integer := 0
  );
  port (
    wb_syscon:    in wb_syscon_type;

    -- Master 0 signals
    m0_wbi:       in wb_mosi_type;
    m0_wbo:       out wb_miso_type;

    -- Master 1 signals
    m1_wbi:       in wb_mosi_type;
    m1_wbo:       out wb_miso_type;

    -- Slave signals
    s0_wbi:       in wb_miso_type;
    s0_wbo:       out wb_mosi_type
  );
end entity wbarb2_1;



architecture behave of wbarb2_1 is

signal current_master: std_logic;
signal next_master: std_logic;
begin

process(wb_syscon.clk)
begin
  if rising_edge(wb_syscon.clk) then
    if wb_syscon.rst='1' then
      current_master <= '0';
    else
      current_master <= next_master;
    end if;
  end if;
end process;


process(current_master, m0_wbi.cyc, m1_wbi.cyc)
begin
  next_master <= current_master;

  case current_master is
    when '0' =>
      if m0_wbi.cyc='0' then
        if m1_wbi.cyc='1' then
          next_master <= '1';
        end if;
      end if;
    when '1' =>
      if m1_wbi.cyc='0' then
        if m0_wbi.cyc='1' then
          next_master <= '0';
        end if;
      end if;
    when others =>
  end case;
end process;

-- Muxers for slave

process(current_master, m0_wbi, m1_wbi)
begin
  case current_master is
    when '0' =>
      s0_wbo.dat <= m0_wbi.dat;
      s0_wbo.adr <= m0_wbi.adr;
      s0_wbo.sel <= m0_wbi.sel;
      s0_wbo.we  <= m0_wbi.we;
      s0_wbo.cyc <= m0_wbi.cyc;
      s0_wbo.stb <= m0_wbi.stb;
      s0_wbo.tag <= m0_wbi.tag;
    when '1' =>
      s0_wbo.dat <= m1_wbi.dat;
      s0_wbo.adr <= m1_wbi.adr;
      s0_wbo.sel <= m1_wbi.sel;
      s0_wbo.we  <= m1_wbi.we;
      s0_wbo.cyc <= m1_wbi.cyc;
      s0_wbo.stb <= m1_wbi.stb;
      s0_wbo.tag <= m1_wbi.tag;
    when others =>
      null;
  end case;
end process;

-- Muxers/sel for masters

m0_wbo.dat <= s0_wbi.dat;
m1_wbo.dat <= s0_wbi.dat;
m0_wbo.tag <= s0_wbi.tag;
m1_wbo.tag <= s0_wbi.tag;
-- Ack

m0_wbo.ack <= s0_wbi.ack when current_master='0' else '0';
m1_wbo.ack <= s0_wbi.ack when current_master='1' else '0';

m0_wbo.stall <= s0_wbi.stall when current_master='0' else '1';
m1_wbo.stall <= s0_wbi.stall when current_master='1' else '1';

end behave;
