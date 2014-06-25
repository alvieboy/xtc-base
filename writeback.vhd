library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.xtcpkg.all;
-- synthesis translate_off
use work.txt_util.all;
-- synthesis translate_on

entity writeback is
  port (
    clk:  in std_logic;
    rst:  in std_logic;

    -- Register 0 access writeback
    r0_en:       out std_logic;
    r0_we:       out std_logic;
    r0_addr:     out regaddress_type;
    r0_write:    out word_type_std;
    -- Register 1 access writeback
    r1_en:       out std_logic;
    r1_we:       out std_logic;
    r1_addr:     out regaddress_type;
    r1_write:    out word_type_std;

    busy:   out std_logic;
    -- Input for previous stages
    mui:  in memory_output_type;
    eui:  in execute_output_type -- For fast register write
  );
end entity writeback;

architecture behave of writeback is

  constant FAST_WRITEBACK: boolean := true;

begin
    process(mui.mregwe,
      eui.reg_source,
      eui.regwe,
      eui.dreg,
      mui.mdata,
      mui.mreg,
      eui.alur1,
      eui.alur2,
      eui.imreg,
      eui.sprval,
      eui.cop
      )
      variable wdata0: unsigned(31 downto 0);
      variable wdata1: unsigned(31 downto 0);
      variable wec: std_logic_vector(1 downto 0);
    begin

      wdata0 := (others => DontCareValue);
      wdata1 := (others => DontCareValue);
      r0_en <= '1';
      r0_we <= '0';
      r0_addr <= (others => DontCareValue);
      r1_en <= '0';
      r1_we <= '0';
      r1_addr <= (others => DontCareValue);
      busy <= '0';

      if mui.mregwe='1' then
        -- Memory access - This means we finish a load
        -- and we need to write contents back to the register
        -- file.

        -- While this happens, we must stall the pipeline if it is trying to wb also.
        -- We can use the second port if we are not writing back two registers
        -- at this point.
          --case eui.reg_source is
         --   when reg_source_alu =>
         --     wdata0 := eui.alur1;
         --   when reg_source_imm =>
         --     wdata0 := eui.imreg;
         --   when reg_source_spr =>
         --     wdata0 := eui.sprval;
         --   when reg_source_pcnext =>
          --    wdata0 := eui.npc;
          --  when others =>
          --    wdata0 := (others => 'X');
          --end case;

          --r0_we <=  eui.regwe;
          --r0_addr <= eui.dreg;
          --r0_en <= '1';

          busy <= eui.regwe;

          --r1_we <=  eui.regwe1;
          --r1_addr <= eui.dreg1;

          wdata0 := unsigned(mui.mdata);
          r0_we <= '1';
          r0_addr <= mui.mreg;

        --case eui.regwe is
        -- when '0' =>
        --    wdata0 := unsigned(mui.mdata);
        --   r0_we <= '1';
        --    r0_addr <= mui.mreg;
        --  when '1' =>
        --    wdata1 := unsigned(mui.mdata);
        --    r1_we <= '1';
        --    r1_addr <= mui.mreg;
        --  when others =>
        --end case;
      else

        if FAST_WRITEBACK then

          case eui.reg_source is
            when reg_source_alu =>
              wdata0 := eui.alur1;
            when reg_source_imm =>
              wdata0 := eui.imreg;
            when reg_source_spr =>
              wdata0 := eui.sprval;
            when reg_source_pcnext=>
              wdata0 := eui.npc;
            when reg_source_cop=>
              wdata0 := unsigned(eui.cop);
            when others =>
              wdata0 := (others => 'X');
          end case;

          r0_we <=  eui.regwe;
          r0_addr <= eui.dreg;

          --r1_we <=  eui.regwe1;
          --r1_addr <= eui.dreg1;

        else

        end if;
      end if;

      r0_write <= std_logic_vector(wdata0);
      r1_write <= std_logic_vector(wdata1);

      -- We must handle SPR register write. This is fed back to
      -- execution unit (and other units if applicable).

    end process;

  end behave;
