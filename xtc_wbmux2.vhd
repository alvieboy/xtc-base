library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
library work;
use work.wishbonepkg.all;

entity xtc_wbmux2 is
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
end entity xtc_wbmux2;



architecture behave of xtc_wbmux2 is

  component reqcnt is
  port (
    clk:  in std_logic;
    rst:  in std_logic;

    stb:  in std_logic;
    cyc:  in std_logic;
    stall:in std_logic;
    ack:  in std_logic;

    req:  out std_logic
  );
  end component;

  signal select_zero: std_logic;
  --signal trcnt0, trcnt1: unsigned(3 downto 0);
  signal t0,t1: std_logic;
  signal qdat,qtag: std_logic_vector(31 downto 0);
  signal queue, queued, qerr: std_logic;
  signal internal_stall:std_logic;
  signal req0,req1: std_logic;
  signal endt0,endt1: std_logic;
begin

select_zero<='1' when m_wbi.adr(select_line)='0' else '0';

req0<=(select_zero and m_wbi.stb) and not internal_stall;
req1<=((not select_zero) and m_wbi.stb) and not internal_stall;

s0_wbo.dat <= m_wbi.dat;
s0_wbo.adr <= m_wbi.adr;
s0_wbo.stb <= req0;--m_wbi.stb and not internal_stall;
s0_wbo.we  <= m_wbi.we;
s0_wbo.sel <= m_wbi.sel;
s0_wbo.tag <= m_wbi.tag;

s1_wbo.dat <= m_wbi.dat;
s1_wbo.adr <= m_wbi.adr;
s1_wbo.stb <= req1;--m_wbi.stb and not internal_stall;
s1_wbo.we  <= m_wbi.we;
s1_wbo.sel <= m_wbi.sel;
s1_wbo.tag <= m_wbi.tag;

cnt0: reqcnt port map (
  clk =>  wb_syscon.clk,
  rst =>  wb_syscon.rst,
  stb =>  req0,
  cyc =>  m_wbi.cyc,
  stall => s0_wbi.stall,
  ack   => endt0,
  req   => t0
  );

  endt0<=s0_wbi.ack or s0_wbi.err;

cnt1: reqcnt port map (
  clk =>  wb_syscon.clk,
  rst =>  wb_syscon.rst,
  stb =>  req1,
  cyc =>  m_wbi.cyc,
  stall => s1_wbi.stall,
  ack   => endt1,
  req   => t1
  );
  endt1 <= s1_wbi.ack or s1_wbi.err;

process(m_wbi.cyc,select_zero,m_wbi.stb,t0,t1)
begin
  if m_wbi.cyc='0' then
    s0_wbo.cyc<='0';
    s1_wbo.cyc<='0';
  else
    s0_wbo.cyc<=(select_zero and m_wbi.stb) or t0;
    s1_wbo.cyc<=(( not select_zero ) and m_wbi.stb) or t1;
  end if;
end process;

process(t0,t1,m_wbi.stb,m_wbi.cyc,select_zero)
begin
  internal_stall<='0';
  if m_wbi.stb='1' and m_wbi.cyc='1' then
    -- Check if same request

    if select_zero='1' and t1='1' then
      internal_stall<='1';
    elsif select_zero='0' and t0='1' then
      internal_stall<='1';
    end if;
  end if;
end process;


process(select_zero,s1_wbi.stall,s0_wbi.stall,internal_stall)
begin
  if select_zero='0' then
    m_wbo.stall<=s1_wbi.stall or internal_stall;
  else
    m_wbo.stall<=s0_wbi.stall or internal_stall;
  end if;
end process;

-- synthesis translate_off
process (wb_syscon.clk)
begin
  if rising_edge(wb_syscon.clk) then
    if is_x(s0_wbi.err) then
      --report "Slave0 'err' is X" severity failure;
    end if;
    if is_x(s1_wbi.err) then
      --report "Slave1 'err' is X" severity failure;
    end if;
  end if;
end process;
-- synthesis translate_on

-- Process responses from both slaves.
-- USE ONLY IN SIMULATION FOR NOW!!!!!



process(s0_wbi,s1_wbi,queued,qdat,qtag)
  variable sel: std_logic_vector(1 downto 0);
begin

  sel(0) := s0_wbi.ack or s0_wbi.err;
  sel(1) := s1_wbi.ack or s1_wbi.err;

  queue <= '0';
  case sel is
    when "00" =>
      if queued='0' then
      m_wbo.ack<='0';
      m_wbo.err<='0';
      m_wbo.dat<=(others => 'X');
      m_wbo.tag<=(others => 'X');
      else
        m_wbo.ack<='1';
        m_wbo.dat<=qdat;
        m_wbo.err<=qerr;
        m_wbo.tag<=qtag;
      end if;
    when "01" =>
      m_wbo.ack<='1';
      m_wbo.dat<=s0_wbi.dat;
      m_wbo.err<=s0_wbi.err;
      m_wbo.tag<=s0_wbi.tag;
    when "10" =>
      m_wbo.ack<='1';
      m_wbo.dat<=s1_wbi.dat;
      m_wbo.err<=s1_wbi.err;
      m_wbo.tag<=s1_wbi.tag;
    when "11" =>
      queue <= '1'; -- Queue S1 request.
      m_wbo.ack<='1';
      m_wbo.dat<=s0_wbi.dat;
      m_wbo.err<=s0_wbi.err;
      m_wbo.tag<=s0_wbi.tag;
    when others => null;
  end case;
end process;

process(wb_syscon.clk)
begin
  if rising_edge(wb_syscon.clk) then
    if wb_syscon.rst='1' then
      queued<='0';
    else
      queued<='0';

      if queue='1' and queued='0' then
        queued<='1';
          qdat <= s1_wbi.dat;
          qtag <= s1_wbi.tag;
          qerr <= s1_wbi.err;

      end if;
    end if;
  end if;
end process;

end behave;
