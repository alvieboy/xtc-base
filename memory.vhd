library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.xtcpkg.all;
-- synthesis translate_off
use work.txt_util.all;
-- synthesis translate_on
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
    wb_stall_i:     in  std_logic;

    busy:           out std_logic;
    refetch:        out std_logic;

    -- Input for previous stages
    eui:  in execute_output_type;
    -- Output for next stages
    muo:  out memory_output_type
  );
end entity memory;

architecture behave of memory is
  signal mr: memory_regs_type;
  signal m_trans: std_logic;
  signal mreg_q: regaddress_type;
  signal mregwe: std_logic;
  signal wb_ack_i_q: std_logic;
begin

    muo.r <= mr;
    muo.mreg <= eui.r.mwreg;--mr.dreg;
    muo.mregwe <= mregwe;

    process(eui,mr,clk,rst,wb_ack_i, wb_ack_i_q, wb_dat_i, wb_stall_i)
      variable mw: memory_regs_type;
      variable wmask: std_logic_vector(3 downto 0);
      variable wdata: std_logic_vector(31 downto 0);
      variable mdata: std_logic_vector(31 downto 0);
    begin

      mw:=mr;
      muo.msprwe<='0';

      wb_cyc_o  <=eui.r.data_access;
      wb_stb_o  <=eui.r.data_access and not mr.trans and not wb_ack_i_q;

      wb_we_o   <=eui.r.data_writeenable;
      wdata     := (others => DontCareValue);
      wmask     := (others => DontCareValue);
      mdata     := (others => '0');

      mw.trans:='0';   -- Transaction delayed.

      if eui.r.data_access='1' and mr.trans='0' and wb_ack_i_q='0'then
        -- requested memory access.
        if wb_stall_i='0' then
          mw.trans:='1';
        end if;
      end if;

      case eui.r.macc is
        when M_BYTE | M_BYTE_POSTINC =>

          case eui.r.data_address(1 downto 0) is
            when "11" =>
              wdata(7 downto 0) := eui.r.data_write(7 downto 0); wmask:="0001";
              mdata(7 downto 0) := wb_dat_i(7 downto 0);

            when "10" =>
              wdata(15 downto 8) := eui.r.data_write(7 downto 0); wmask:="0010";
              mdata(7 downto 0) := wb_dat_i(15 downto 8);

            when "01" =>
              wdata(23 downto 16) := eui.r.data_write(7 downto 0); wmask:="0100";
              mdata(7 downto 0) := wb_dat_i(23 downto 16);

            when "00" =>
              wdata(31 downto 24) := eui.r.data_write(7 downto 0); wmask:="1000";
              mdata(7 downto 0) := wb_dat_i(31 downto 24);

            when others => null;
          end case;


        when M_HWORD | M_HWORD_POSTINC =>
          case eui.r.data_address(1) is
            when '1' =>
              wdata(15 downto 0) := eui.r.data_write(15 downto 0); wmask:="0011";
              mdata(15 downto 0) := wb_dat_i(15 downto 0);
            when '0' =>
              wdata(31 downto 16) := eui.r.data_write(15 downto 0); wmask:="1100";
              mdata(15 downto 0) := wb_dat_i(31 downto 16);

            when others => null;
          end case;

        when others =>
          wdata := eui.r.data_write;
          wmask:="1111";
          mdata := wb_dat_i;

      end case;

      wb_adr_o <= eui.r.data_address;
      wb_sel_o <= wmask;
      wb_dat_o <= wdata;
      refetch <= '0';

      mregwe <= '0';
      mw.dreg := eui.r.mwreg;

      if eui.r.data_access='1' and wb_ack_i_q='0' and eui.r.data_writeenable='0' then
        -- NOTE: if we just issued a store, and a load is queued, we also need to
        -- refetch the data. Maybe use freeze.... ????
        refetch <= wb_ack_i;
        --if wb_ack_i='1' then
          mregwe <= not eui.r.sprwe;
          muo.msprwe <= eui.r.sprwe;
        --else
          --mregwe <= '0';
          --muo.msprwe <= '0';
        --end if;
      end if;

      busy <= '0';

      if eui.r.data_access='1' and wb_ack_i_q/='1' then
        busy <= '1';
      end if;

      if eui.r.data_access='0' then
        wb_cyc_o <= '0';
        wb_stb_o <= DontCareValue;
        wb_adr_o <= (others => DontCareValue);
        wb_dat_o <= (others => DontCareValue);
        wb_sel_o <= (others => DontCareValue);
      end if;

      if rst='1' then
        wb_cyc_o <= '0';
        wb_stb_o <= DontCareValue;
        wb_adr_o <= (others => DontCareValue);
        wb_dat_o <= (others => DontCareValue);
        wb_sel_o <= (others => DontCareValue);
        mw.trans := '0';
      end if;

      muo.mdata <= mdata;

      if rising_edge(clk) then
        wb_ack_i_q <= wb_ack_i;
        -- synthesis translate_off
        if DEBUG_MEMORY then
        if eui.r.data_access='1' and wb_ack_i='1' then
          if eui.r.data_writeenable='1' then
            report ">> MEMORY WRITE, address " & hstr(eui.r.data_address) & ", data 0x" & hstr( wdata );
          else
            report ">> MEMORY READ, address " & hstr(eui.r.data_address) & " <= " & hstr(mdata);
          end if;
        end if;
        end if;
        -- synthesis translate_on
        mr<=mw;
      end if;

    end process;
  end behave;
