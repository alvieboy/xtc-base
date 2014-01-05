library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.xtcpkg.all;
use work.xtccomppkg.all;
-- synthesis translate_off
use work.txt_util.all;
-- synthesis translate_on


entity execute is
  port (
    clk:  in std_logic;
    rst:  in std_logic;
    mem_busy: in std_logic;
    busy: out std_logic;
    refetch: in std_logic;
    wb_busy: in std_logic;

    int:  in std_logic;
    intline: in std_logic_vector(7 downto 0);

    -- Input for previous stages
    fdui:  in fetchdata_output_type;

    -- Output for next stages
    euo:  out execute_output_type;

    -- Input from memory unit, for SPR update
    mui:  in memory_output_type

  );
end entity execute;

architecture behave of execute is

  signal alu_a_a, alu_a_b: std_logic_vector(31 downto 0);
  signal alu_a_r: unsigned(31 downto 0);
  signal alu_b_a, alu_b_b: std_logic_vector(31 downto 0);
  signal alu_b_r: unsigned(31 downto 0);
  signal alu1_ci, alu1_co, alu1_busy, alu1_ovf, alu1_sign, alu1_zero: std_logic;
  signal alu2_ci, alu2_co, alu2_busy, alu2_ovf, alu2_sign, alu2_zero: std_logic;
  signal er: execute_regs_type;
  signal dbg_do_interrupt: boolean;

begin

  euo.r <= er;
  alu_a_a <= fdui.rr1;
  alu_a_b <= fdui.rr2;
  alu_b_a <= fdui.rr3;


  myaluA: alu_A
    port map (
      clk   => clk,
      rst   => rst,
  
      a     => unsigned(alu_a_a),
      b     => unsigned(alu_a_b),
      o     => alu_a_r,
      op    => fdui.r.drq.alu1_op,
      ci    => er.psr(30),
      busy  => alu1_busy,
      co    => alu1_co,
      zero  => alu1_zero,
      ovf   => alu1_ovf,
      sign  => alu1_sign
    );

  myaluB: alu_B
    port map (
      clk   => clk,
      rst   => rst,
  
      a     => unsigned(alu_b_a),
      b     => unsigned(alu_b_b),
      o     => alu_b_r,
      op    => fdui.r.drq.alu2_op,
      co    => alu2_co,
      zero  => alu2_zero,
      sign  => alu2_sign
    );

  process(clk,fdui,er,rst,alu_a_r,alu_b_r,
          alu1_co, alu1_sign,alu1_zero,alu1_ovf,
          alu2_co, alu2_zero,
          mem_busy,wb_busy,int)
    variable ew: execute_regs_type;
    variable busy_int: std_logic;
    constant reg_zero: unsigned(31 downto 0) := (others => '0');
    variable im8_fill: unsigned(31 downto 0);
    variable invalid_instr: boolean;
    variable spr: unsigned(31 downto 0);
    variable can_interrupt: boolean;
    variable do_interrupt: boolean;

  begin
    ew := er;

    ew.valid := fdui.r.drq.valid;
    ew.jump := '0';
    ew.jumpaddr := (others => 'X');
    can_interrupt := true;
    do_interrupt := false;

    ew.regwe0 := '0';
    ew.regwe1 := '0';

    invalid_instr := false;

    alu_b_b <= fdui.rr4;

    if fdui.r.drq.alu2_imreg='1' then
      alu_b_b <= std_logic_vector(fdui.r.drq.imreg);
    end if;

    if fdui.r.drq.imflag='0' then
      can_interrupt := true;
    end if;

    if can_interrupt and int='1' and er.psr(4)='1' and fdui.r.drq.valid='1' and fdui.r.drq.jump_clause=JUMP_NONE
        and er.jump='0' then
      do_interrupt := true;
    end if;

    if ( mem_busy='1' and fdui.r.drq.memory_access='1' ) or
      -- Load must stall pipeline for now
      ( mem_busy='1' and er.data_access='1' and er.data_writeenable='0' )
      then
      busy_int := '1';
    else
      busy_int := wb_busy;
    end if;

    if mem_busy='0' then
      ew.data_access := '0';
    end if;

    if fdui.r.drq.valid='1' and
      busy_int='0' and er.intjmp=false then
      -- synthesis translate_off
      if DEBUG_OPCODES then
        if rising_edge(clk) then
           report hstr(std_logic_vector(fdui.r.drq.pc)) & " " & fdui.r.drq.strasm;
        end if;
      end if;
      -- synthesis translate_on

      ew.alur1 := alu_a_r(31 downto 0);
      ew.alur2 := alu_b_r(31 downto 0);
      
      ew.wb_is_data_address := fdui.r.drq.wb_is_data_address;

      if fdui.r.drq.modify_flags then
        case fdui.r.drq.flags_source is
          when FLAGS_ALU1 =>
            ew.psr(30)      := alu1_co;
            ew.psr(31)      := alu1_sign;
            ew.psr(28)      := alu1_ovf;
            ew.psr(29)      := alu1_zero;
          when FLAGS_ALU2 =>
            ew.psr(30)      := alu2_co;
            ew.psr(31)      := alu2_sign;
            ew.psr(29)      := alu2_zero;
            ew.psr(28)      := 'X';
          when others =>
        end case;
      end if;

      ew.reg_source0  := fdui.r.drq.reg_source0;
      ew.regwe0       := fdui.r.drq.regwe0;
      ew.dreg0        := fdui.r.drq.dreg0;

      ew.reg_source1  := fdui.r.drq.reg_source1;
      ew.regwe1       := fdui.r.drq.regwe1;
      ew.dreg1        := fdui.r.drq.dreg1;

      ew.sprwe        := fdui.r.drq.sprwe;

      ew.mwreg    := fdui.r.drq.sra4;
      ew.sr       := fdui.r.drq.sr;

      if mem_busy='0' or refetch='1' then
        ew.macc := fdui.r.drq.macc;

        case fdui.r.drq.macc is
          when M_SPR | M_SPR_POSTINC =>
            -- TODO: add missing SPRs
            case fdui.r.drq.sra4(2 downto 0) is
              when others =>
                ew.data_write := std_logic_vector(er.br);
            end case;
          when others =>
            ew.data_write := fdui.rr4; -- Memory always go through Alu2
        end case;

        case fdui.r.drq.macc is
          when M_WORD  |
               M_HWORD |
               M_BYTE  |
               M_SPR =>
            ew.data_address := std_logic_vector(alu_b_r);
          when M_WORD_POSTINC |
               M_HWORD_POSTINC |
               M_BYTE_POSTINC |
               M_SPR_POSTINC =>
            --ew.data_address := std_logic_vector(alu_b_r);
            ew.data_address := fdui.rr3;

          when others =>
            invalid_instr := true;
        end case;

        ew.data_access := fdui.r.drq.memory_access;
        ew.data_writeenable := fdui.r.drq.memory_write;
      else
        --alu_b_b <= (others => 'X');
      end if;
        if fdui.r.drq.memory_access='1' then
          case fdui.r.drq.macc is
            when M_WORD_POSTINC | M_SPR_POSTINC =>
              alu_b_b <= x"00000004";
            when M_HWORD_POSTINC =>
              alu_b_b <= x"00000002";
            when M_BYTE_POSTINC =>
              alu_b_b <= x"00000001";
            when others =>
              alu_b_b <= std_logic_vector(fdui.r.drq.imreg);
          end case;
        end if;

      -- Branching
      case fdui.r.drq.jump_clause is
        when JUMP_NONE =>           ew.jump := '0';
        when JUMP_INCONDITIONAL =>  ew.jump := '1';
        when JUMP_NE =>             ew.jump := not er.psr(29);
        when JUMP_E =>              ew.jump := er.psr(29);
        when JUMP_GE =>             ew.jump := not er.psr(31);
        when JUMP_G =>              ew.jump := not er.psr(31) and not er.psr(29);
        when JUMP_LE =>             ew.jump := er.psr(31) or er.psr(29);
        when JUMP_L =>              ew.jump := er.psr(31);
        when JUMP_UGE =>            ew.jump := not er.psr(30);
        when JUMP_UG =>             ew.jump := not er.psr(30) or er.psr(29);
        when JUMP_ULE =>            ew.jump := er.psr(30) or er.psr(29);
        when JUMP_UL =>             ew.jump := er.psr(30);
        when others =>              ew.jump := '0';
      end case;

      case fdui.r.drq.jump is
        when JUMP_RI_PCREL => ew.jumpaddr := alu_b_r(31 downto 0) + fdui.r.drq.npc(31 downto 0);
        when JUMP_I_PCREL =>  ew.jumpaddr := fdui.r.drq.imreg + fdui.r.drq.npc(31 downto 0);
        when JUMP_BR_ABS =>   ew.jumpaddr := er.br;
        when JUMP_RI_ABS =>   ew.jumpaddr := alu_b_r;
        when others =>        ew.jumpaddr := (others => 'X');
      end case;

      -- Never jump if busy
      if busy_int='1' then
        ew.jump := '0';
      end if;

      case fdui.r.drq.br_source is
        when br_source_pc =>    ew.br := fdui.r.drq.fpc;  -- This is PC+2. We have to skip delay slot
        when br_source_reg =>   ew.br := unsigned(fdui.rr1);
        --when br_source_brs =>   ew.br := er.brs;
        when others =>          -- Keep
      end case;

      if fdui.r.drq.sprwe='1' and fdui.r.drq.memory_access='0' then
        case fdui.r.drq.sra2(2 downto 0) is
          when "000" => -- PC
          when "001" => -- BR
          when "010" => -- Y
          when "011" => -- PSR
            ew.psr := unsigned(fdui.rr1);
          when "100" => -- SPSR
            ew.spsr := unsigned(fdui.rr1);
          when "101" => -- SBR
            ew.brs := unsigned(fdui.rr1);
          when "110" => -- TTR
            ew.trapvector := unsigned(fdui.rr1);

          when others =>
        end case;
      end if;

      if ew.jump='1' and fdui.r.drq.except_return then
        -- Restore PSR, BR
        ew.psr := ew.spsr;
        ew.br := ew.brs;
      end if;


    else
      -- Instruction is not being processed.
      -- Make sure all combinatory circuits do not present
      -- overhead.

      alu_b_b <= (others => 'X');
    end if;

    if mui.msprwe='1' then
      case mui.mreg(2 downto 0) is
        when "001" =>
          ew.br := unsigned(mui.mdata);
        when "010" =>
          -- CPU Status register

        when others =>
      end case;
    end if;

    ew.intjmp := false;

    if busy_int='0' and do_interrupt then
      ew.jump := '1';
      ew.intjmp := true;
      ew.jumpaddr(31 downto 2) := er.trapvector(31 downto 2);
      ew.jumpaddr(1 downto 0) := "00";
      ew.psr(4) := '0'; -- Interrupt enable
      ew.psr(0) := '1'; -- Supervisor mode
      ew.spsr := er.psr; -- Save PSR
      ew.brs  := er.br; -- Save branch register
      ew.br := fdui.r.drq.npc;
    end if;

    busy <= busy_int;

    -- Fast writeback
    euo.alur1 <= alu_a_r(31 downto 0);
    euo.alur2 <= alu_b_r(31 downto 0);

    -- REG sources are also per ALU
    euo.reg_source0  <= ew.reg_source0;
    euo.dreg0        <= ew.dreg0;
    euo.regwe0       <= ew.regwe0;
    euo.reg_source1  <= ew.reg_source1;
    euo.dreg1        <= ew.dreg1;
    euo.regwe1       <= ew.regwe1;

    euo.sprwe        <= er.sprwe;
    -- SPRVAL...

    case fdui.r.drq.sra2(2 downto 0) is
      when "000" => euo.sprval <= fdui.r.drq.fpc;
      when "001" => euo.sprval <= er.br;
      when "010" => euo.sprval <= er.y;
      when "011" => euo.sprval <= er.psr;
      when "100" => euo.sprval <= er.spsr;
      when "101" => euo.sprval <= er.brs;
      when "110" => euo.sprval <= er.trapvector;
      when others => euo.sprval <= (others => 'X');
    end case;

    euo.imreg       <= fdui.r.drq.imreg;
    euo.sr          <= ew.sr;

    if rst='1' then
      ew.psr(0) := '1'; -- Supervisor
      ew.psr(4) := '0'; -- Interrupts disabled
      ew.trapvector := (others => '0');
    end if;

    if rising_edge(clk) then
      if invalid_instr then
        report "Invalid instruction" severity failure;
      end if;
      er <= ew;
    end if;
    -- synthesis translate_off
    dbg_do_interrupt <= do_interrupt;
    -- synthesis translate_on
  end process;

end behave;
