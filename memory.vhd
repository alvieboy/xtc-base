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

    busy:           out std_logic;

    -- Input for previous stages
    eui:  in execute_output_type;
    -- Output for next stages
    muo:  out memory_output_type
  );
end entity memory;

architecture behave of memory is
  signal mr: memory_regs_type;
  signal m_trans: std_logic;
begin

    muo.r <= mr;
    muo.mdata <= wb_dat_i;

    process(eui,mr,clk,rst)
      variable mw: memory_regs_type;
      variable wmask: std_logic_vector(3 downto 0);
    begin

      mw:=mr;

      wb_cyc_o  <=eui.r.data_access;
      wb_stb_o  <=eui.r.data_access;
      wb_we_o   <=eui.r.data_writeenable;
      wb_dat_o <= (others => DontCareValue);
      wmask    := (others => DontCareValue);

      case eui.r.mask is
        when MASK_8 =>
          case eui.r.data_address(1 downto 0) is
            when "00" => wb_dat_o(7 downto 0) <= eui.r.data_write(7 downto 0); wmask:="0001";
            when "01" => wb_dat_o(15 downto 8) <= eui.r.data_write(7 downto 0); wmask:="0010";
            when "10" => wb_dat_o(23 downto 16) <= eui.r.data_write(7 downto 0); wmask:="0100";
            when "11" => wb_dat_o(31 downto 24) <= eui.r.data_write(7 downto 0); wmask:="1000";
            when others => null;
          end case;
        when MASK_16 =>
          case eui.r.data_address(1) is
            when '0' => wb_dat_o(15 downto 0) <= eui.r.data_write(15 downto 0); wmask:="0011";
            when '1' => wb_dat_o(31 downto 16) <= eui.r.data_write(15 downto 0); wmask:="1100";
            when others => null;
          end case;
        when MASK_32 =>
            wb_dat_o <= eui.r.data_write;
            wmask:="1111";
        when others => null;
      end case;

      wb_adr_o  <= eui.r.data_address;
      wb_sel_o  <= wmask;

      mw.mread := '0';
      if eui.r.data_access='1' and eui.r.data_writeenable='0' then
        mw.mread:='1';
      end if;

      busy <= '0';

      if eui.r.data_access='1' and wb_ack_i/='1' then
        busy <= '1';
      end if;

      if eui.r.valid='0' then
        wb_cyc_o <= '0';
        wb_stb_o <= DontCareValue;
        wb_adr_o <= (others => DontCareValue);
        wb_dat_o <= (others => DontCareValue);
        wb_sel_o <= (others => DontCareValue);
      end if;

      if eui.r.valid='1' then
        mw.wb_is_data_address := eui.r.wb_is_data_address;

        mw.alur1 := eui.r.alur1;
        mw.alur2 := eui.r.alur2;

        mw.data_address := eui.r.data_address;
        mw.regwe := eui.r.regwe;
        mw.dreg := eui.r.dreg;
      end if;

      if rst='1' then
        wb_cyc_o <= '0';
        wb_stb_o <= DontCareValue;
        wb_adr_o <= (others => DontCareValue);
        wb_dat_o <= (others => DontCareValue);
        wb_sel_o <= (others => DontCareValue);
        mw.mread:='0';
      end if;                     

      if rising_edge(clk) then
        mr<=mw;
      end if;

    end process;
  end behave;
