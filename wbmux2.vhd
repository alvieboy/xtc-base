library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
library work;
use work.wishbonepkg.all;

entity wbmux2 is
  generic (
    select_line: integer;
    address_high: integer:=31;
    address_low: integer:=2
  );
  port (
    wb_syscon:  in wb_syscon_type;
    -- Master 
    m_wbi:       in wb_mosi_type;
    m_wbo:       out wb_miso_type;
    -- Slave signals
    s0_wbo:       out wb_mosi_type;
    s0_wbi:       in wb_miso_type;
    s1_wbo:       out wb_mosi_type;
    s1_wbi:       in wb_miso_type
  );
end entity wbmux2;



architecture behave of wbmux2 is

signal select_zero: std_logic;

begin

select_zero<='1' when m_wbi.adr(select_line)='0' else '0';

s0_wbo.dat <= m_wbi.dat;
s0_wbo.adr <= m_wbi.adr;
s0_wbo.stb <= m_wbi.stb;
s0_wbo.we  <= m_wbi.we;
s0_wbo.sel <= m_wbi.sel;
s0_wbo.tag <= m_wbi.tag;

s1_wbo.dat <= m_wbi.dat;
s1_wbo.adr <= m_wbi.adr;
s1_wbo.stb <= m_wbi.stb;
s1_wbo.we  <= m_wbi.we;
s1_wbo.sel <= m_wbi.sel;
s1_wbo.tag <= m_wbi.tag;

process(m_wbi.cyc,select_zero)
begin
  if m_wbi.cyc='0' then
    s0_wbo.cyc<='0';
    s1_wbo.cyc<='0';
  else
    s0_wbo.cyc<=select_zero;
    s1_wbo.cyc<=not select_zero;
  end if;
end process;

process(select_zero,s1_wbi.stall,s0_wbi.stall)
begin
  if select_zero='0' then
    m_wbo.stall<=s1_wbi.stall;
  else
    m_wbo.stall<=s0_wbi.stall;
  end if;
end process;

-- Process responses from both slaves.
-- USE ONLY IN SIMULATION FOR NOW!!!!!

process(s0_wbi,s1_wbi)
  variable sel: std_logic_vector(1 downto 0);
begin
  sel := s1_wbi.ack & s0_wbi.ack;
  case sel is
    when "00" =>
      m_wbo.ack<='0';
      m_wbo.dat<=(others => 'X');
      m_wbo.tag<=(others => 'X');
    when "01" =>
      m_wbo.ack<='1';
      m_wbo.dat<=s0_wbi.dat;
      m_wbo.tag<=s0_wbi.tag;
    when "10" =>
      m_wbo.ack<='1';
      m_wbo.dat<=s1_wbi.dat;
      m_wbo.tag<=s1_wbi.tag;
    when others =>
      m_wbo.ack<='U';
      m_wbo.dat<=(others => 'X');
      m_wbo.tag<=(others => 'X');
  end case;
end process;

end behave;
