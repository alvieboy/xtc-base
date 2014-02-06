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
    -- Register access
    r3_en:      out std_logic;
    r3_addr:    out regaddress_type;
    r3_read:    in word_type_std;
    -- Register access
    r4_en:      out std_logic;
    r4_addr:    out regaddress_type;
    r4_read:    in word_type_std;

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
  fduo.rr3 <= r3_read;
  fduo.rr4 <= r4_read;


  syncfetch: if FETCHDATA_STAGE generate

    process(dui,clk,rst,fdr,flush,freeze, refetch)
      variable fdw: fetchdata_regs_type;
    begin
      fdw := fdr;

      fduo.valid <= fdr.drq.valid;

      if freeze='0' then
        fdw.drq := dui.r;
        fdw.rd1q   := dui.r.rd1;
        fdw.rd2q   := dui.r.rd2;
        fdw.rd3q   := dui.r.rd3;
        fdw.rd4q   := dui.r.rd4;

        if flush='1' then
          fdw.drq.valid:='0';
        end if;
      end if;

      if rst='1' then
        fdw.drq.valid := '0';
      end if;

      if refetch='1' then
        --fduo.valid <= '0';
        if freeze='0' then
        fdw.drq.valid := '0';
        end if;

        --r1_en <= fdr.rd1q;
        --r2_en <= fdr.rd2q;
        --r3_en <= fdr.rd3q;
        --r4_en <= fdr.rd4q;

        --r1_addr <= fdr.drq.sra1;
        --r2_addr <= fdr.drq.sra2;
        --r3_addr <= fdr.drq.sra3;
        --r4_addr <= fdr.drq.sra4;
      end if;
      --else
      if freeze='1' then
        r1_en   <= '0';
        r2_en   <= '0';
        r3_en   <= '0';
        r4_en   <= '0';
      else
        r1_en   <= dui.r.rd1;
        r2_en   <= dui.r.rd2;
        r3_en   <= dui.r.rd3;
        r4_en   <= dui.r.rd4;
      end if;
        r1_addr <= dui.r.sra1;
        r2_addr <= dui.r.sra2;
        r3_addr <= dui.r.sra3;
        r4_addr <= dui.r.sra4;
      --end if;

      if rising_edge(clk) then
        fdr <= fdw;
      end if;
    end process;



  end generate;

  asyncfetch: if not FETCHDATA_STAGE generate

    fdr.drq <= dui.r;
    process(fdr,refetch, dui)
    begin
      if refetch='1' then
        r1_en <= '1';
        r2_en <= '1';
        r3_en <= '1';
        r4_en <= '1';
        r1_addr <= fdr.drq.sra1;
        r2_addr <= fdr.drq.sra2;
        r3_addr <= fdr.drq.sra3;
        r4_addr <= fdr.drq.sra4;
      else
        r1_en <= dui.rd1;
        r2_en <= dui.rd2;
        r3_en <= dui.rd3;
        r4_en <= dui.rd4;
        r1_addr <= dui.sra1;
        r2_addr <= dui.sra2;
        r3_addr <= dui.sra3;
        r4_addr <= dui.sra4;
      end if;
    end process;

  end generate;

end behave;
