library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.newcpupkg.all;

entity fetchdata is
  port (
    clk:  in std_logic;
    rst:  in std_logic;
    -- Register access
    r_en:   out std_logic;
    r_we:   out std_logic;
    r_addr:   out regaddress_type;
    r_write:   out word_type_std;
    r_read:   in word_type_std;
    -- Input for previous stages
    dui:  in decode_output_type;

    -- Output for next stages
    fduo:  out fetchdata_output_type
  );
end entity fetchdata;

architecture behave of fetchdata is

  signal fdr: fetchdata_regs_type;

begin

  fduo.r <= fdr;
  fduo.rr <= r_read;

  process(dui,clk,rst,fdr)
    variable fdw: fetchdata_regs_type;
  begin
    fdw := fdr;
    fdw.drq := dui.r;

    r_we <= '0';
    r_write <= (others => DontCareValue);
    r_en <= dui.r.rd1;
    r_addr <= dui.r.source.gpr;

    if rising_edge(clk) then
      fdr <= fdw;
    end if;
  end process;

end behave;
