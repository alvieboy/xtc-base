library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.newcpupkg.all;

entity memory is
  port (
    clk:  in std_logic;
    rst:  in std_logic;
    -- Memory interface
    wb_ack_i:       in std_logic;
    wb_dat_i:       in std_logic_vector(31 downto 0);
    wb_dat_o:       out std_logic_vector(31 downto 0);
    wb_adr_o:       out std_logic_vector(31 downto 0);
    wb_cyc_o:       out std_logic;
    wb_stb_o:       out std_logic;
    wb_sel_o:       out std_logic_vector(3 downto 0);
    wb_we_o:        out std_logic;
    -- Input for previous stages
    eui:  in execute_output_type;
    -- Output for next stages
    muo:  out memory_output_type
  );
end entity memory;

architecture behave of memory is
  signal mr: memory_regs_type;
begin

    muo.r <= mr;
    muo.mdata <= wb_dat_i;

    process(eui,mr,clk,rst)
      variable mw: memory_regs_type;
    begin
      mw:=mr;
      -- mw.erq := eui.r;

      wb_cyc_o<=eui.r.data_access;
      wb_stb_o<=eui.r.data_access;
      wb_we_o<=eui.r.data_writeenable;
      wb_dat_o<=eui.r.data_write;
      wb_adr_o<=eui.r.data_address;

      mw.mread := '0';
      if eui.r.data_access='1' and eui.r.data_writeenable='0' then
        mw.mread:='1';
      end if;

      if eui.r.valid='0' then
        wb_cyc_o <= '0';
      end if;

      if rst='1' then
        mw.mread:='0';
      end if;                     

      if eui.r.valid='1' then
        mw.wb_is_data_address := eui.r.wb_is_data_address;
        mw.alur := eui.r.alur;
        mw.data_address := eui.r.data_address;
        mw.rb2_we := eui.r.rb2_we;
      end if;

      if rising_edge(clk) then
        mr<=mw;
      end if;

    end process;
  end behave;
