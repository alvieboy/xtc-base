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
    -- Input for previous stages
    mui:  in memory_output_type;
    eui:  in execute_output_type -- For fast register write
  );
end entity writeback;

architecture behave of writeback is
begin
    process(mui,eui)
      variable wdata: unsigned(31 downto 0);
    begin
      wdata := (others => DontCareValue);
      r_en <= '1';
      --if mui.r.mread='1' then
        --if eui.r.fdrq.drq.wb_is_data_address='0' then
        --  r_write <=  std_logic_vector(eui.r.alur);
        --else
        case eui.r.reg_source is
          when reg_source_alu1 =>
            wdata := eui.r.alur1;
          when reg_source_alu2 =>
            wdata := eui.r.alur2;
          when others =>
        end case;
        r_write <= std_logic_vector(wdata);--std_logic_vector(eui.r.data_address);
        --end if;
        r_we <=  eui.r.regwe;
        r_addr <= eui.r.dreg;

      --else
      --  if mui.r.wb_is_data_address='0' then
          --
      --    r_write <=  std_logic_vector(wdata);--std_logic_vector(mui.r.alur);
--        else
  --        r_write <=  std_logic_vector(mui.r.data_address);
   --     end if;
--        r_we <=  mui.r.regwe;
--        r_addr <= mui.r.dreg;
--      end if;
    end process;

  end behave;
