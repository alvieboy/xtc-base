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
    wb_tag_o:       out std_logic_vector(31 downto 0);
    wb_tag_i:       in std_logic_vector(31 downto 0);
    wb_err_i:       in std_logic;
    wb_cyc_o:       out std_logic;
    wb_stb_o:       out std_logic;
    wb_sel_o:       out std_logic_vector(3 downto 0);
    wb_we_o:        out std_logic;
    wb_stall_i:     in  std_logic;

    busy:           out std_logic;
    refetch:        out std_logic;
  
    dbgo:           out memory_debug_type;

    protw:          in std_logic_vector(31 downto 0);
    proten:         in std_logic;

    -- Input for previous stages
    eui:  in execute_output_type;
    -- Output for next stages
    muo:  out memory_output_type
  );
end entity memory;

architecture behave of memory is
  signal mr: memory_regs_type;
  signal mreg_q: regaddress_type;
  signal wb_ack_i_q: std_logic;
  signal cycle_fault:std_logic;

  component reqcnt is
  port (
    clk:  in std_logic;
    rst:  in std_logic;

    stb:  in std_logic;
    cyc:  in std_logic;
    stall:in std_logic;
    ack:  in std_logic;

    req:  out std_logic;
    count:  out unsigned(2 downto 0)
  );
  end component;

  signal req_pending: std_logic;
  signal endcycle:    std_logic;
    -- debug only
  signal busycnt: unsigned(31 downto 0);

  signal faultw: std_logic;

begin

    muo.r <= mr;
    muo.fault <= mr.fault;

    process(eui,mr,clk,rst,wb_ack_i, wb_ack_i_q, wb_dat_i, wb_stall_i, wb_tag_i, wb_err_i,
            req_pending)
      variable mw: memory_regs_type;
      variable wmask: std_logic_vector(3 downto 0);
      variable wdata: std_logic_vector(31 downto 0);
      variable mdata: std_logic_vector(31 downto 0);
      variable queue_request:   boolean;
      variable mrsel: std_logic_vector(2 downto 0);
    begin

      mw:=mr;

      wdata     := (others => DontCareValue);
      wmask     := (others => DontCareValue);
      mdata     := (others => '0');

      mw.fault  := '0';

      case eui.macc is
        when M_BYTE | M_BYTE_POSTINC =>

          case eui.data_address(1 downto 0) is
            when "11" => wdata(7 downto 0)   := eui.data_write(7 downto 0); wmask:="0001"; mrsel:="000";
            when "10" => wdata(15 downto 8)  := eui.data_write(7 downto 0); wmask:="0010"; mrsel:="001";
            when "01" => wdata(23 downto 16) := eui.data_write(7 downto 0); wmask:="0100"; mrsel:="010";
            when "00" => wdata(31 downto 24) := eui.data_write(7 downto 0); wmask:="1000"; mrsel:="011";
            when others => null;
          end case;

        when M_HWORD | M_HWORD_POSTINC =>
          case eui.data_address(1) is
            when '1' => wdata(15 downto 0)  := eui.data_write(15 downto 0); wmask:="0011"; mrsel:="100";
            when '0' => wdata(31 downto 16) := eui.data_write(15 downto 0); wmask:="1100"; mrsel:="101";
            when others => null;
          end case;

        when others =>
          wdata := eui.data_write; wmask:="1111"; mrsel := "111";
      end case;

     -- queue_request := false;

      muo.mregwe <= '0';
      muo.msprwe <= '0';

      queue_request := true;
      busy<='0';
      if wb_stall_i='1' and mr.wb_stb='1' then
        queue_request := false;
        busy<='1';
      end if;


      case wb_tag_i(7 downto 5) is
        when "000" => mdata(7 downto 0) := wb_dat_i(7 downto 0);
        when "001" => mdata(7 downto 0) := wb_dat_i(15 downto 8);
        when "010" => mdata(7 downto 0) := wb_dat_i(23 downto 16);
        when "011" => mdata(7 downto 0) := wb_dat_i(31 downto 24);
        when "100" => mdata(15 downto 0) := wb_dat_i(15 downto 0);
        when "101" => mdata(15 downto 0) := wb_dat_i(31 downto 16);
        when "110" => mdata := (others => 'X');
        when others => mdata := wb_dat_i;
      end case;

      if mr.wb_cyc='1' and wb_stall_i='0' then
        mw.wb_cyc:='0';
      end if;

      if queue_request then
        mw.wb_we   := eui.data_writeenable;
        mw.wb_dat  := wdata;
        mw.wb_adr  := eui.data_address;
        mw.wb_tago := (others => 'X');
        mw.wb_tago(3 downto 0) := eui.mwreg(3 downto 0);
        mw.wb_tago(4) := not eui.data_writeenable;
        mw.wb_tago(7 downto 5) := mrsel;
        mw.wb_tago(8) := eui.mwreg(4);
        mw.macc    := eui.macc;
        mw.wb_sel  := wmask;
        mw.wb_stb  := eui.data_access;
        mw.wb_cyc  := eui.data_access;
        mw.sprwe   := eui.sprwe and not eui.data_writeenable;
        mw.regwe   := (not eui.sprwe) and not eui.data_writeenable;
        mw.dreg    := eui.mwreg;
        mw.pc      := eui.npc;

        if proten='1' and LOWPROTECTENABLE then
          if eui.data_writeenable='1' and eui.data_access='1' then
            if (unsigned(eui.data_address)<unsigned(protw)) then
              mw.fault := '1';
              mw.wb_stb := '0';
              mw.faddr := std_logic_vector(eui.npc);
            end if;
          end if;
        end if;

      end if;


      muo.mdata <= mdata;

      muo.mreg <= wb_tag_i(8) & wb_tag_i(3 downto 0);

      muo.mregwe <= wb_ack_i and wb_tag_i(4);

      refetch <= wb_ack_i and wb_tag_i(4);

      if queue_request and eui.clrreg='1' then
        muo.mregwe<='1';
        muo.mreg<=eui.mwreg;
      end if;

      if wb_err_i='1' then
        mw.fault := '1';
      end if;

      if rst='1' then
        mw.wb_cyc := '0';
        mw.wb_stb := '0';
        mw.fault  := '0';
      end if;

      if rising_edge(clk) then
        mr<=mw;
      end if;

    end process;


    -- debug
        dbgo.strobe <= mr.wb_stb and not wb_stall_i;
        dbgo.write  <= mr.wb_we;
        dbgo.address  <= unsigned(mr.wb_adr);
        dbgo.data  <= unsigned(mr.wb_dat);
        dbgo.pc  <= unsigned(mr.pc);
        dbgo.faddr <= unsigned(mr.faddr);
  -- Counter

  endcycle <= wb_ack_i or wb_err_i;



  cnt0: reqcnt port map (
  clk =>  clk,
  rst =>  rst,
  stb =>  mr.wb_stb,
  cyc => '1',
  stall => wb_stall_i,
  ack   => endcycle,
  req   => req_pending,
  count => open
  );

  wb_adr_o <= mr.wb_adr;
  wb_stb_o <= mr.wb_stb;
  wb_dat_o <= mr.wb_dat;
  wb_we_o  <= mr.wb_we;
  wb_sel_o <= mr.wb_sel;
  wb_tag_o <= mr.wb_tago;
  wb_cyc_o <= req_pending or mr.wb_cyc;

  faultcheck: if FAULTCHECKS generate
    -- Internal fault...
    process(clk)
    begin
      if rising_edge(clk) then
        if rst='1' then
          busycnt<=(others =>'0');
        else
          if mr.wb_cyc='1' and endcycle='0' then
            busycnt<=busycnt+1;
          else
            busycnt<=(others =>'0');
          end if;
  
        end if;
      end if;
    end process;
  
    -- Cycle check.
    cycle_fault<='1' when (req_pending or mr.wb_cyc) /= (req_pending or mr.wb_stb) else '0';
  
    muo.internalfault<='1' when busycnt > 65535 or cycle_fault='1' else '0';
  end generate;

  nofaultcheck: if not FAULTCHECKS generate
    cycle_fault<='0';
    muo.internalfault<='0';
  end generate;


end behave;
