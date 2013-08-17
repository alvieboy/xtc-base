library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.newcpupkg.all;

entity taint is
  port (
    clk: in std_logic;
    rst: in std_logic;

    req1_en: in std_logic;
    req1_r: in regaddress_type;

    req2_en: in std_logic;
    req2_r: in regaddress_type;

    ready:  out std_logic;

    set_en:  in std_logic;
    set_r:   in regaddress_type;
    clr_en:  in std_logic;
    clr_r:   in regaddress_type;

    taint:  out std_logic_vector(7 downto 0)
  );
end taint;

architecture behave of taint is

  signal t: std_logic_vector(7 downto 0);
  signal req1_ok: std_logic;
  signal req2_ok: std_logic;

begin

  process(req1_en, req1_r, clr_en, clr_r)
    variable idx: integer range 0 to 7;
  begin
    if req1_en='0' then
      req1_ok<='1';
    else
      idx := to_integer(unsigned(req1_r));
      if clr_en='1' and clr_r=req1_r then
        req1_ok <= '1';
      else
        req1_ok <= t(idx);
      end if;
    end if;
  end process;

  process(req2_en, req2_r, clr_en, clr_r)
    variable idx: integer range 0 to 7;
  begin
    if req2_en='0' then
      req2_ok<='1';
    else
      idx := to_integer(unsigned(req2_r));
      if clr_en='1' and clr_r=req2_r then
        req2_ok <= '1';
      else
        req2_ok <= t(idx);
      end if;
    end if;
  end process;

  ready <= req1_ok and req2_ok;

  process(clk)
    variable idxs,idxc: integer range 0 to 7;
  begin
  if rising_edge(clk) then
    if rst='1' then
      t <= (others => '1');
    else
      idxs := to_integer(unsigned(set_r));
      idxc := to_integer(unsigned(clr_r));

      if set_en='1' then
        t(idxs) <= '0';
      end if;

      if clr_en='1' then
        t(idxc) <= '1';
      end if;
      
    end if;
  end if;
end process;
end behave;