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
    mui:  in memory_output_type;

    dbgo: out execute_debug_type

  );
end entity execute;

architecture behave of execute is

  signal alu_a_a, alu_a_b: std_logic_vector(31 downto 0);
  signal alu_a_r: unsigned(31 downto 0);
  --signal alu_b_a, alu_b_b: std_logic_vector(31 downto 0);
  --signal alu_b_r: unsigned(31 downto 0);
  signal alu1_ci, alu1_co, alu1_busy, alu1_ovf, alu1_sign, alu1_zero: std_logic;
  --signal alu2_ci, alu2_co, alu2_busy, alu2_ovf, alu2_sign, alu2_zero: std_logic;
  signal er: execute_regs_type;
  signal dbg_do_interrupt: boolean;

  signal enable_alu: std_logic;

  signal lhs,rhs: std_logic_vector(31 downto 0);

begin

  lhs<=fdui.rr1 when fdui.alufwa='0' else std_logic_vector(er.alur);
  rhs<=fdui.rr2 when fdui.alufwb='0' else std_logic_vector(er.alur);

  euo.r <= er;
  alu_a_a <= lhs;
  alu_a_b <= rhs when fdui.r.drq.alu_source = alu_source_reg else std_logic_vector(fdui.r.drq.imreg);

  dbgo.lhs <= unsigned(alu_a_a);
  dbgo.rhs <= unsigned(alu_a_b);

  myalu: alu
    port map (
      clk   => clk,
      rst   => rst,
  
      a     => unsigned(alu_a_a),
      b     => unsigned(alu_a_b),
      o     => alu_a_r,
      en    => enable_alu,   -- Check...
      op    => fdui.r.drq.alu_op,
      ci    => er.psr(30),
      cen   => fdui.r.drq.use_carry,
      busy  => alu1_busy,
      co    => alu1_co,
      zero  => alu1_zero,
      ovf   => alu1_ovf,
      sign  => alu1_sign
    );

  process(clk,fdui,er,rst,alu_a_r,
          alu1_co, alu1_sign,alu1_zero,alu1_ovf,
          mui,
          mem_busy,wb_busy,int)
    variable ew: execute_regs_type;
    variable busy_int: std_logic;
    constant reg_zero: unsigned(31 downto 0) := (others => '0');
    variable im8_fill: unsigned(31 downto 0);
    variable invalid_instr: boolean;
    variable spr: unsigned(31 downto 0);
    variable can_interrupt: boolean;
    variable do_interrupt: boolean;
    variable passes_condition: std_logic;
    variable reg_add_immed: unsigned(31 downto 0);

    alias psr_carry:  std_logic   is  er.psr(30);
    alias psr_sign:   std_logic   is  er.psr(31);
    alias psr_ovf:    std_logic   is  er.psr(28);
    alias psr_zero:   std_logic   is  er.psr(29);

  begin
    ew := er;

    ew.valid := fdui.valid;
    ew.jump := '0';
    ew.jumpaddr := (others => 'X');
    can_interrupt := true;
    do_interrupt := false;

    ew.regwe := '0';
    enable_alu <= '0';

    invalid_instr := false;

    reg_add_immed := unsigned(lhs) + fdui.r.drq.imreg;

    --alu_b_b <= fdui.rr4;

    -- Conditional execution
    case fdui.r.drq.condition_clause is
      when CONDITION_UNCONDITIONAL =>  passes_condition := '1';
      when CONDITION_NE =>             passes_condition := not er.psr(29);
      when CONDITION_E =>              passes_condition := er.psr(29);
      when CONDITION_GE =>             passes_condition := not er.psr(31);
      when CONDITION_G =>              passes_condition := not er.psr(31) and not er.psr(29);
      when CONDITION_LE =>             passes_condition := er.psr(31) or er.psr(29);
      when CONDITION_L =>              passes_condition := er.psr(31);
      when CONDITION_UGE =>            passes_condition := not er.psr(30);
      when CONDITION_UG =>             passes_condition := not er.psr(30) or er.psr(29);
      when CONDITION_ULE =>            passes_condition := er.psr(30) or er.psr(29);
      when CONDITION_UL =>             passes_condition := er.psr(30);
      when others =>                   passes_condition := 'X';
    end case;



    if fdui.r.drq.imflag='0' then
      can_interrupt := true;
    end if;

    --if can_interrupt and int='1' and er.psr(4)='1' and fdui.valid='1' and fdui.r.drq.jump_clause=JUMP_NONE
    --    and er.jump='0' then
    --  do_interrupt := true;
    --end if;

    if mem_busy='1' or alu1_busy='1' then
      busy_int := '1';
    else
      busy_int := wb_busy;
    end if;

    -- synthesis translate_off
    if DEBUG_OPCODES then
      if rising_edge(clk) then
        if fdui.valid='1' and busy_int='0' and er.intjmp=false then
          if fdui.r.drq.dual then
            report hstr(std_logic_vector(fdui.r.drq.pc)) & " " & hstr(fdui.r.drq.opcode)&hstr(fdui.r.drq.opcode_low);
          else
            report hstr(std_logic_vector(fdui.r.drq.pc)) & " " & hstr(fdui.r.drq.opcode);
          end if;
        elsif fdui.valid='0' then
          report hstr(std_logic_vector(fdui.r.drq.pc)) & " <NOT VALID>" ;
        elsif busy_int='1' then
          report hstr(std_logic_vector(fdui.r.drq.pc)) & " <BUSY>" ;
        elsif er.intjmp then
          report hstr(std_logic_vector(fdui.r.drq.pc)) & " <JUMP>" ;
        end if;
      end if;
    end if;
    -- synthesis translate_on

    euo.reg_source  <= fdui.r.drq.reg_source;
    euo.dreg         <= fdui.r.drq.dreg;

    if fdui.valid='1' and er.intjmp=false and passes_condition='1' then
      euo.regwe        <= fdui.r.drq.regwe;
    else
      euo.regwe        <= '0';
    end if;

    dbgo.valid <= false;
    dbgo.executed <= false;
    euo.executed <= false;

    if fdui.valid='1' and busy_int='0' and er.intjmp=false then
      dbgo.valid <= true;
      if passes_condition='1' then
        dbgo.executed <= true;
        euo.executed <= true;
      end if;
    end if;

    dbgo.dual <= fdui.r.drq.dual;
    dbgo.opcode1 <= fdui.r.drq.opcode_low;
    dbgo.opcode2 <= fdui.r.drq.opcode;
    dbgo.pc <= fdui.r.drq.pc;

    if fdui.valid='1' and busy_int='0' and er.intjmp=false and passes_condition='1' then

      ew.alur := alu_a_r(31 downto 0);

      ew.alufwa := fdui.r.alufwa;
      ew.alufwb := fdui.r.alufwb;

      ew.wb_is_data_address := fdui.r.drq.wb_is_data_address;

      if fdui.r.drq.modify_flags then
            ew.psr(30)      := alu1_co;
            ew.psr(31)      := alu1_sign;
            ew.psr(28)      := alu1_ovf;
            ew.psr(29)      := alu1_zero;
      end if;

      ew.reg_source  := fdui.r.drq.reg_source;
      ew.regwe       := fdui.r.drq.regwe;
      ew.dreg        := fdui.r.drq.dreg;
      ew.npc         := fdui.r.drq.npc;

      if fdui.r.drq.is_jump and passes_condition='1' then
        ew.jump:='1';
      else
        ew.jump:='0';
      end if;

      case fdui.r.drq.jump is
        --when JUMP_RI_PCREL => ew.jumpaddr := reg_add_immed + fdui.r.drq.npc(31 downto 0);
        when JUMP_I_PCREL =>  ew.jumpaddr := fdui.r.drq.imreg + fdui.r.drq.npc(31 downto 0);
        when JUMP_RI_ABS =>   ew.jumpaddr := reg_add_immed;
        when others =>        ew.jumpaddr := (others => 'X');
      end case;

      -- Never jump if busy
      if busy_int='1' then
        ew.jump := '0';
      end if;

      if fdui.r.drq.sprwe='1' and fdui.r.drq.memory_access='0' then
        case fdui.r.drq.sra2(1 downto 0) is
          when "00" => -- Y
          when "01" => -- PSR
            ew.psr := unsigned(lhs);
          when "10" => -- SPSR
            ew.spsr := unsigned(lhs);
          when "11" => -- TTR
            ew.trapvector := unsigned(lhs);

          when others =>
        end case;
      end if;

      if ew.jump='1' and fdui.r.drq.except_return then
        -- Restore PSR, BR
        ew.psr := er.spsr;
      end if;

      enable_alu <= fdui.r.drq.enable_alu;

    else
      -- Instruction is not being processed.
      -- Make sure all combinatory circuits do not present
      -- overhead.

      --alu_b_b <= (others => 'X');
    end if;

    --if mui.msprwe='1' then
    --  case mui.mreg(2 downto 0) is
    --    when others =>
    --  end case;
    --end if;

    ew.intjmp := false;

    if busy_int='0' and do_interrupt then
      ew.jump := '1';
      ew.intjmp := true;
      ew.jumpaddr(31 downto 2) := er.trapvector(31 downto 2);
      ew.jumpaddr(1 downto 0) := "00";
      ew.psr(4) := '0'; -- Interrupt enable
      ew.psr(0) := '1'; -- Supervisor mode
      ew.spsr := er.psr; -- Save PSR
    end if;

    busy <= busy_int;

    -- Fast writeback
    euo.alur <= alu_a_r(31 downto 0);

    -- SPRVAL...

    case fdui.r.drq.sra2(1 downto 0) is
      when "00" => ew.sprval := er.y;
      when "01" => ew.sprval := er.psr;
      when "10" => ew.sprval := er.spsr;
      when "11" => ew.sprval := er.trapvector;
      when others => ew.sprval := (others => 'X');
    end case;

    euo.sprval <= ew.sprval;

    euo.imreg       <= fdui.r.drq.imreg;
    euo.sr          <= ew.sr;


    -- Memory lines

    euo.sprwe     <= fdui.r.drq.sprwe;
    euo.mwreg     <= fdui.r.drq.sra2;
    euo.sr        <= fdui.r.drq.sr;
    euo.macc      <= fdui.r.drq.macc;
    euo.npc       <= fdui.r.drq.fpc;  -- NOTE: This is due to delay slot

    euo.data_write <= (others => 'X');

    case fdui.r.drq.macc is
     -- when M_SPR | M_SPR_POSTINC =>
        -- TODO: add missing SPRs

      when others =>
        euo.data_write <= rhs; -- Memory always go through Alu2
    end case;

    euo.data_address      <= std_logic_vector(reg_add_immed);
    euo.data_access       <= fdui.r.drq.memory_access;
    euo.data_writeenable  <= fdui.r.drq.memory_write;

    if fdui.valid='0' or passes_condition='0' then
      euo.data_access <= '0';
    end if;

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
