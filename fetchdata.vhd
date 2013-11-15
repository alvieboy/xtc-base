library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.xtcpkg.all;

entity fetchdata is
  port (
    clk:  in std_logic;
    rst:  in std_logic;
    -- Register access
    r1_en:      out std_logic;
    r1_addr:    out regaddress_type;
    r1_read:    in word_type_std;
    -- Register access
    r2_en:      out std_logic;
    r2_addr:    out regaddress_type;
    r2_read:    in word_type_std;

    w_addr:     out regaddress_type;
    w_en:       out std_logic;

    -- Input for previous stages
    dui:  in decode_output_type;

    freeze: in std_logic;
    flush:  in std_logic;
    refetch: in std_logic;
    
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

  syncfetch: if false generate

    process(dui,clk,rst,fdr,flush,freeze, refetch)
      variable fdw: fetchdata_regs_type;
    begin
      fdw := fdr;
      if freeze='0' then
        fdw.drq := dui.r;
        if flush='1' or rst='1' then
          fdw.drq.valid:='0';
        end if;
      end if;
      -- This is only to check for conflicts
--      w_addr <= dui.r.dreg;
--      w_en   <= dui.r.regwe;
      --
      r1_en   <= dui.r.rd1;
      r2_en   <= dui.r.rd2;
      r1_addr <= dui.r.sra1;
      r2_addr <= dui.r.sra2;
  
      if rising_edge(clk) then
        fdr <= fdw;
      end if;
    end process;

  end generate;

  asyncfetch: if true generate

    fdr.drq <= dui.r;
    process(fdr,refetch, dui)
    begin
      if refetch='1' then
        r1_en <= '1';
        r2_en <= '1';
        r1_addr <= fdr.drq.sra1;
        r2_addr <= fdr.drq.sra2;
      else
        r1_en <= dui.rd1;
        r2_en <= dui.rd2;
        r1_addr <= dui.sra1;
        r2_addr <= dui.sra2;
      end if;
    end process;

  end generate;

end behave;
