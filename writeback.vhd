library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.newcpupkg.all;

entity writeback is
  port (
    clk:  in std_logic;
    rst:  in std_logic;
    -- Register access
    r_en:   out std_logic;
    r_we:   out std_logic;
    r_addr:   out regaddress_type;
    r_write:   out word_type_std;
    busy:   out std_logic;
    -- Input for previous stages
    mui:  in memory_output_type;
    eui:  in execute_output_type -- For fast register write
  );
end entity writeback;

architecture behave of writeback is

  constant FAST_WRITEBACK: boolean := true;

begin
    process(mui,eui)
      variable wdata: unsigned(31 downto 0);
    begin

      wdata := (others => DontCareValue);
      r_en <= '1';
      r_addr <= (others => DontCareValue);

      if mui.mregwe='1' then
        -- Memory access - This means we finish a load
        -- and we need to write contents back to the register
        -- file.
        -- While this happens, we must stall the pipeline if it is trying to wb also
        busy <= eui.r.regwe;
        wdata := unsigned(mui.mdata);
        r_we <= '1';
        r_addr <= mui.mreg;
      else
        busy <= '0';
        if FAST_WRITEBACK then

        case eui.reg_source is
          when reg_source_alu1 =>
            wdata := eui.alur1;
          when reg_source_alu2 =>
            wdata := eui.alur2;
          when reg_source_imm =>
            wdata := eui.imreg;
          when reg_source_spr =>

            wdata := eui.r.br;

          when others =>
        end case;
  
        r_we <=  eui.regwe;
        r_addr <= eui.dreg;
        else

        case eui.r.reg_source is
          when reg_source_alu1 =>
            wdata := eui.r.alur1;
          when reg_source_alu2 =>
            wdata := eui.r.alur2;
          when reg_source_imm =>
            wdata := eui.r.imreg;
          when reg_source_spr =>
            wdata := eui.r.br;
          when others =>
        end case;
  
        r_we <=  eui.r.regwe;
        r_addr <= eui.r.dreg;

        end if;
      end if;

      r_write <= std_logic_vector(wdata);
    end process;

  end behave;
