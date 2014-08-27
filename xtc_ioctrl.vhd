library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbonepkg.all;
use work.xtcpkg.all;

entity xtc_ioctrl is
  port (
    syscon:     in wb_syscon_type;
    wbi:        in wb_mosi_type;
    wbo:        out wb_miso_type;
    -- Slaves
    swbi:       in slot_wbi;
    swbo:       out slot_wbo;
    sids:       in slot_ids
  );
end entity xtc_ioctrl;


architecture behave of xtc_ioctrl is

  signal selector: std_logic_vector(15 downto 0);
  signal selnum: integer range 0 to 15;
  
begin

  process(wbi.adr)
    variable num: integer range 0 to 15;
  begin
    num := to_integer(unsigned(wbi.adr(30 downto 28)));
    selector<=(others => '0');
    selector(num)<='1';
    selnum<=num;
  end process;
    
  wbo.dat <= swbi(selnum).dat;
  wbo.ack <= swbi(selnum).ack;
  wbo.stall <= '0';

  -- Simple tag generator
  process(syscon.clk)
  begin
    if rising_edge(syscon.clk) then
       --if wbi.cyc='1' and wbi.stb='1' and wbo.ack='0' then
          wbo.tag <= wbi.tag;
       --end if;
    end if;
  end process;


  slavegen: for i in 0 to 15 generate
    swbo(i).adr <= wbi.adr;
    swbo(i).dat <= wbi.dat;
    swbo(i).we  <= wbi.we;
    --swbo(i).tag <= wbi.tag;
    swbo(i).cyc <= wbi.cyc and selector(i);
    swbo(i).stb <= wbi.stb and selector(i);
  end generate;


end behave;
