library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity wbmux2 is
  generic (
    select_line: integer;
    address_high: integer:=31;
    address_low: integer:=2
  );
  port (
    wb_clk_i: in std_logic;
	 	wb_rst_i: in std_logic;

    -- Master 

    m_wb_dat_o: out std_logic_vector(31 downto 0);
    m_wb_dat_i: in std_logic_vector(31 downto 0);
    m_wb_tag_o: out std_logic_vector(31 downto 0);
    m_wb_tag_i: in std_logic_vector(31 downto 0);
    m_wb_adr_i: in std_logic_vector(address_high downto address_low);
    m_wb_sel_i: in std_logic_vector(3 downto 0);
    m_wb_we_i:  in std_logic;
    m_wb_cyc_i: in std_logic;
    m_wb_stb_i: in std_logic;
    m_wb_ack_o: out std_logic;
    m_wb_stall_o: out std_logic;

    -- Slave 0 signals

    s0_wb_dat_i: in std_logic_vector(31 downto 0);
    s0_wb_dat_o: out std_logic_vector(31 downto 0);
    s0_wb_tag_i: in std_logic_vector(31 downto 0);
    s0_wb_tag_o: out std_logic_vector(31 downto 0);
    s0_wb_adr_o: out std_logic_vector(address_high downto address_low);
    s0_wb_sel_o: out std_logic_vector(3 downto 0);
    s0_wb_we_o:  out std_logic;
    s0_wb_cyc_o: out std_logic;
    s0_wb_stb_o: out std_logic;
    s0_wb_ack_i: in std_logic;
    s0_wb_stall_i: in std_logic;

    -- Slave 1 signals

    s1_wb_dat_i: in std_logic_vector(31 downto 0);
    s1_wb_dat_o: out std_logic_vector(31 downto 0);
    s1_wb_tag_i: in std_logic_vector(31 downto 0);
    s1_wb_tag_o: out std_logic_vector(31 downto 0);
    s1_wb_adr_o: out std_logic_vector(address_high downto address_low);
    s1_wb_sel_o: out std_logic_vector(3 downto 0);
    s1_wb_we_o:  out std_logic;
    s1_wb_cyc_o: out std_logic;
    s1_wb_stb_o: out std_logic;
    s1_wb_ack_i: in std_logic;
    s1_wb_stall_i: in std_logic
  );
end entity wbmux2;



architecture behave of wbmux2 is

signal select_zero: std_logic;

begin

select_zero<='1' when m_wb_adr_i(select_line)='0' else '0';

s0_wb_dat_o <= m_wb_dat_i;
s0_wb_adr_o <= m_wb_adr_i;
s0_wb_stb_o <= m_wb_stb_i;
s0_wb_we_o  <= m_wb_we_i;
s0_wb_sel_o <= m_wb_sel_i;
s0_wb_tag_o <= m_wb_tag_i;

s1_wb_dat_o <= m_wb_dat_i;
s1_wb_adr_o <= m_wb_adr_i;
s1_wb_stb_o <= m_wb_stb_i;
s1_wb_we_o  <= m_wb_we_i;
s1_wb_sel_o <= m_wb_sel_i;
s1_wb_tag_o <= m_wb_tag_i;

process(m_wb_cyc_i,select_zero)
begin
  if m_wb_cyc_i='0' then
    s0_wb_cyc_o<='0';
    s1_wb_cyc_o<='0';
  else
    s0_wb_cyc_o<=select_zero;
    s1_wb_cyc_o<=not select_zero;
  end if;
end process;

process(select_zero,s1_wb_dat_i,s0_wb_dat_i,s0_wb_ack_i,s0_wb_tag_i,
        s1_wb_ack_i,s0_wb_stall_i,s1_wb_stall_i,s1_wb_tag_i)
begin
  if select_zero='0' then
    m_wb_stall_o<=s1_wb_stall_i;
  else
    m_wb_stall_o<=s0_wb_stall_i;
  end if;
end process;

-- Process responses from both slaves.
-- USE ONLY IN SIMULATION FOR NOW!!!!!

process(s0_wb_ack_i,s0_wb_dat_i,s0_wb_tag_i,
        s1_wb_ack_i,s1_wb_dat_i,s1_wb_tag_i)
  variable sel: std_logic_vector(1 downto 0);
begin
  sel := s1_wb_ack_i & s0_wb_ack_i;
  case sel is
    when "00" =>
      m_wb_ack_o<='0';
      m_wb_dat_o<=(others => 'X');
      m_wb_tag_o<=(others => 'X');
    when "01" =>
      m_wb_ack_o<='1';
      m_wb_dat_o<=s0_wb_dat_i;
      m_wb_tag_o<=s0_wb_tag_i;
    when "10" =>
      m_wb_ack_o<='1';
      m_wb_dat_o<=s1_wb_dat_i;
      m_wb_tag_o<=s1_wb_tag_i;
    when others =>
      m_wb_ack_o<='U';
      m_wb_dat_o<=(others => 'X');
      m_wb_tag_o<=(others => 'X');
  end case;
end process;

end behave;
