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
    r1_en:   out std_logic;
    r1_addr:   out regaddress_type;
    r1_read:   in word_type_std;
    -- Register access
    r2_en:   out std_logic;
    r2_addr:   out regaddress_type;
    r2_read:   in word_type_std;
    w_addr: out regaddress_type;
    w_en:     out std_logic;
    -- Input for previous stages
    dui:  in decode_output_type;

    freeze: in std_logic;
    -- Output for next stages
    fduo:  out fetchdata_output_type
  );
end entity fetchdata;

architecture behave of fetchdata is

  signal fdr: fetchdata_regs_type;

begin

  fduo.r <= fdr;
  fduo.rr1 <= r1_read;
  fduo.rr2 <= r2_read;

  process(dui,clk,rst,fdr)
    variable fdw: fetchdata_regs_type;
  begin
    fdw := fdr;
    if freeze='0' then
      fdw.drq := dui.r;
    end if;
    -- This is only to check for conflicts
    w_addr <= dui.r.dreg;
    w_en   <= dui.r.regwe;
    r1_en <= dui.r.rd1;
    r2_en <= dui.r.rd2;
    r1_addr <= dui.r.sra1;
    r2_addr <= dui.r.sra2;

    if rising_edge(clk) then
      fdr <= fdw;
    end if;
  end process;

end behave;
