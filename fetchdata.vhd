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

    clrhold:    in std_logic;
    executed:   in boolean;
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

  fduo.alufwa <= fdr.alufwa;
  fduo.alufwb <= fdr.alufwb;

  syncfetch: if FETCHDATA_STAGE generate

    process(dui,clk,rst,fdr,flush,freeze, refetch, executed)
      variable fdw: fetchdata_regs_type;
    begin
      fdw := fdr;

      fduo.valid <= fdr.drq.valid;-- or (fdr.waiting and not refetch);
      if freeze='0' then
        fdw.drq     := dui.r;
        fdw.rd1q    := dui.r.rd1;
        fdw.rd2q    := dui.r.rd2;
        if dui.r.valid='1' then
          fdw.hold    := dui.r.ismult;
        end if;

        -- Forwarding control

        fdw.alu:='0';
        fdw.alufwa:='0';
        fdw.alufwb:='0';

        if ( dui.r.reg_source = reg_source_alu ) then
          if dui.r.regwe='1' then
            fdw.alu:='1';
            fdw.dreg := dui.r.dreg;
          end if;
        end if;

        if (fdr.alu='1' and dui.r.sra1=fdr.dreg and executed and fdr.dreg/="0000") then
          fdw.alufwa:='1';
        end if;

        if (fdr.alu='1' and dui.r.sra2=fdr.dreg and executed and fdr.dreg/="0000") then
          fdw.alufwb:='1';
        end if;

        if flush='1' then
          fdw.drq.valid:='0';
          fdw.alu:='0';
        end if;

      end if;


      fdw.waiting:='0';

      if refetch='1' then
        if freeze='0' then
          fdw.drq.valid := '0';
          fdw.waiting:='1';
        end if;
      end if;

      if freeze='1' or flush='1' then
        r1_en   <= '0';
        r2_en   <= '0';
      else
        r1_en   <= dui.r.rd1;
        r2_en   <= dui.r.rd2;
      end if;

      r1_addr <= dui.r.sra1;
      r2_addr <= dui.r.sra2;
      w_addr <= dui.r.dreg;
      w_en   <= dui.r.regwe;

      if clrhold='1' then
        fdw.hold := '0';

        if dui.r.valid='1' then
          fdw.hold    := dui.r.ismult;
        end if;
        -- REMOVE ME.....
        --fdw.drq.enable_alu := '0';
      end if;
      if flush='1' then
        fdw.hold := '0';
      end if;

      if rst='1' then
        fdw.drq.valid := '0';
        fdw.hold := '0';
      end if;


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
        --r3_en <= '1';
        --r4_en <= '1';
        r1_addr <= fdr.drq.sra1;
        r2_addr <= fdr.drq.sra2;
        --r3_addr <= fdr.drq.sra3;
        --r4_addr <= fdr.drq.sra4;
      else
        r1_en <= dui.rd1;
        r2_en <= dui.rd2;
        --r3_en <= dui.rd3;
        --r4_en <= dui.rd4;
        r1_addr <= dui.sra1;
        r2_addr <= dui.sra2;
        --r3_addr <= dui.sra3;
        --r4_addr <= dui.sra4;
      end if;
    end process;

  end generate;

end behave;
