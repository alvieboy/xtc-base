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
    nmi:  in std_logic;
    nmiack:  out std_logic;
    -- Input for previous stages
    fdui:  in fetchdata_output_type;

    -- Output for next stages
    euo:  out execute_output_type;

    -- Input from memory unit, for SPR update
    mui:  in memory_output_type;
    -- Coprocessor interface
    co:   out copo;
    ci:   in  copi;
    dbgo: out execute_debug_type

  );
end entity execute;

architecture behave of execute is

  signal alu_a_a, alu_a_b: std_logic_vector(31 downto 0);
  signal alu_a_r, alu_a_y: unsigned(31 downto 0);
  --signal alu_b_a, alu_b_b: std_logic_vector(31 downto 0);
  --signal alu_b_r: unsigned(31 downto 0);
  signal alu1_ci, alu1_co, alu1_busy, alu1_ovf, alu1_sign, alu1_zero: std_logic;
  --signal alu2_ci, alu2_co, alu2_busy, alu2_ovf, alu2_sign, alu2_zero: std_logic;
  signal er: execute_regs_type;
  signal dbg_do_interrupt: boolean;

  signal enable_alu: std_logic;

  signal lhs,rhs: std_logic_vector(31 downto 0);

  signal cop_busy, cop_en: std_logic;
  signal do_trap: std_logic;
  signal mult_valid: std_logic;
  signal dbg_passes_condition: std_logic;

begin

  lhs<=fdui.rr1 when fdui.alufwa='0' else std_logic_vector(er.alur);
  rhs<=fdui.rr2 when fdui.alufwb='0' else std_logic_vector(er.alur);

  euo.r <= er;
  alu_a_a <= lhs;
  alu_a_b <= rhs when fdui.r.drq.alu_source = alu_source_reg else std_logic_vector(fdui.r.drq.imreg);

  dbgo.lhs <= unsigned(alu_a_a);
  dbgo.rhs <= unsigned(alu_a_b);

  dbgo.lhs <= unsigned(alu_a_a);
  dbgo.rhs <= unsigned(alu_a_b);

  dbgo.dbgen <= er.psr(2);

  myalu: alu
    port map (
      clk   => clk,
      rst   => rst,
  
      a     => unsigned(alu_a_a),
      b     => unsigned(alu_a_b),
      o     => alu_a_r,
      y     => alu_a_y,
      en    => enable_alu,   -- Check...
      op    => fdui.r.drq.alu_op,
      ci    => er.psr(30),
      cen   => fdui.r.drq.use_carry,
      busy  => alu1_busy,
      valid => mult_valid,
      co    => alu1_co,
      zero  => alu1_zero,
      ovf   => alu1_ovf,
      sign  => alu1_sign
    );

  co.en<=cop_en;

  cop_busy<='1' when cop_en='1' and ci.valid/='1' else '0';

  process(clk,fdui,er,rst,alu_a_r,
          alu1_co, alu1_sign,alu1_zero,alu1_ovf,
          mem_busy,wb_busy,int,cop_busy,lhs,alu1_busy,ci,rhs,mult_valid)
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
    variable trap:  boolean;

    variable do_fault: boolean;
    variable fault_address: unsigned(3 downto 0);
  begin
    ew := er;

    ew.valid := fdui.valid;
    -- Note: with delay slots, we must only reset JUMP when
    -- we finished executing the slot.
    if fdui.valid='1' then
      ew.jump := '0';
      ew.jumpaddr := (others => 'X');
    end if;

    can_interrupt := true;
    do_interrupt := false;
    do_fault := false;
    fault_address:=(others => 'X');
    trap:=false;
    nmiack <= '0';

    if wb_busy='0' then
      ew.regwe := '0';
    end if;

    enable_alu <= '0';

    invalid_instr := false;

    reg_add_immed := unsigned(lhs) + fdui.r.drq.imreg;

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
      when CONDITION_UG =>             passes_condition := not er.psr(30) and not er.psr(29);
      when CONDITION_ULE =>            passes_condition := er.psr(30) or er.psr(29);
      when CONDITION_UL =>             passes_condition := er.psr(30);
      when others =>                   passes_condition := 'X';
    end case;

    if mem_busy='1' or cop_busy='1' then
      busy_int := '1';
    else
      busy_int := wb_busy;
    end if;

    -- synthesis translate_off
    if DEBUG_OPCODES then
      if rising_edge(clk) then
        if fdui.valid='1' and busy_int='0' then
          if fdui.r.drq.dual then
            report hstr(std_logic_vector(fdui.r.drq.pc)) & " " & hstr(fdui.r.drq.opcode)&hstr(fdui.r.drq.opcode_low);
          else
            report hstr(std_logic_vector(fdui.r.drq.pc)) & " " & hstr(fdui.r.drq.opcode);
          end if;
        elsif fdui.valid='0' then
          report hstr(std_logic_vector(fdui.r.drq.pc)) & " <NOT VALID>" ;
        elsif busy_int='1' then
          report hstr(std_logic_vector(fdui.r.drq.pc)) & " <BUSY>" ;
        --elsif er.intjmp then
         -- report hstr(std_logic_vector(fdui.r.drq.pc)) & " <JUMP>" ;
        end if;
      end if;
    end if;
    -- synthesis translate_on

    euo.reg_source  <= fdui.r.drq.reg_source;
    euo.dreg         <= fdui.r.drq.dreg;

    dbgo.valid <= false;
    dbgo.executed <= false;
    euo.executed <= false;

    dbgo.dual <= fdui.r.drq.dual;
    dbgo.opcode1 <= fdui.r.drq.opcode_low;
    dbgo.opcode2 <= fdui.r.drq.opcode;
    dbgo.pc <= fdui.r.drq.pc;


    dbgo.hold <= fdui.r.hold;
    dbgo.multvalid <= mult_valid;

    if fdui.valid='1' and passes_condition='1' then
      enable_alu <= fdui.r.drq.enable_alu;
    end if;

    cop_en <= '0';
    co.wr <= 'X';
    co.reg <= fdui.r.drq.cop_reg;
    co.id <= fdui.r.drq.cop_id;
    co.data <= lhs;



    -- Note: if this happens in a delay slot.... the result is
    -- undefined.

    if fdui.valid='1' and (fdui.r.drq.priv='1' and er.psr(0)='0') then
      trap:=true;
      do_fault:=true;
      can_interrupt:=false;
      fault_address:=x"1";
    end if;

    if ci.fault='1' then
      trap:=true;
      do_fault:=true;
      can_interrupt:=false;
      fault_address:=x"1";
    end if;

    -- Traps and interrupts.

    if can_interrupt and fdui.valid='1' and fdui.r.drq.decoded=O_SWI then
      do_interrupt := true;
      do_fault:=true;
      fault_address:=x"2";
    end if;


    if can_interrupt and int='1' and er.psr(1)='1' and fdui.valid='1' and er.jump='0' then
      do_interrupt := true;
      do_fault:=true;
      fault_address:=x"0";
    end if;

    if mui.fault='1' then
      do_fault:=true;
      fault_address:=x"3";
    end if;

    if nmi='1' and er.innmi='0' then --and er.jump='0' and fdui.valid='1' then
      do_fault:=true;
      fault_address:=x"4";
      ew.innmi :='1';
      nmiack<='1';
    end if;


    if fdui.valid='1' and busy_int='0' then
      dbgo.valid <= true;
      if passes_condition='1' then
        dbgo.executed <= true;
        euo.executed <= true;
      end if;
    end if;

  

    do_trap<='0';
    ew.trapq:='0';
    dbgo.trap<='0';
    if do_fault then
      passes_condition := '0';
      do_trap<='1';
      ew.trapq := '1';
      dbgo.trap <= '1';
      dbgo.valid <= false;
    end if;



    if fdui.valid='1' and passes_condition='1' then
      cop_en <= fdui.r.drq.cop_en;
      co.wr <= fdui.r.drq.cop_wr;
    end if;

    if fdui.valid='1' and passes_condition='0' and fdui.r.drq.blocks='1' then
      euo.clrreg    <= '1';
    else
      euo.clrreg    <= '0';
    end if;

    if fdui.valid='1' and busy_int='0' then

     if passes_condition='1' then
      ew.alur := alu_a_r(31 downto 0);

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
      ew.npc         := fdui.r.drq.fpc;

      if fdui.r.drq.is_jump then
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
      --if busy_int='1' then
      --  ew.jump := '0';
      --end if;
     end if; -- passes condition

      if fdui.r.drq.sprwe='1' and fdui.r.drq.memory_access='0' then
        case fdui.r.drq.sra2(2 downto 0) is
          when "000" => -- Y
            ew.y := unsigned(lhs);
          when "001" => -- PSR
            ew.psr(7 downto 0) := unsigned(lhs(7 downto 0));
            ew.psr(31 downto 28) := unsigned(lhs(31 downto 28));
          when "010" => -- SPSR
            ew.spsr(7 downto 0) := unsigned(lhs(7 downto 0));
            ew.spsr(31 downto 28) := unsigned(lhs(31 downto 28));
          when "011" => -- TTR
            ew.trapvector := unsigned(lhs);
          when "100" => -- TPC
            ew.trappc := unsigned(lhs);
          when "101" => -- SR
            ew.scratch := unsigned(lhs);

          when others =>
        end case;
      end if;

      if ew.jump='1' and fdui.r.drq.except_return then
        -- Restore PSR, BR
        ew.psr(7 downto 0) := er.spsr(7 downto 0);
        ew.psr(31 downto 28) := er.spsr(31 downto 28);
        ew.jumpaddr := er.trappc;
        ew.innmi:='0';
      end if;

    else
      -- Instruction is not being processed.
      enable_alu<='0';
    end if;

    if do_fault then
      --ew.jump:='1';
      ew.jumpaddr(31 downto 8):=er.trapvector(31 downto 8);
      ew.jumpaddr(7 downto 4) := fault_address;
      ew.jumpaddr(3 downto 0) := x"0";
      ew.spsr := ew.psr; -- Save PSR
      ew.psr(2) := '0'; -- Debug enabled.
      ew.psr(1) := '0'; -- Interrupt enable
      ew.psr(0) := '1'; -- Supervisor mode
      ew.psr(7 downto 4) := fault_address;

      --ew.psr(1) := fdui.r.drq.imflag;
      ew.trappc := fdui.r.drq.tpc;
    end if;

    busy <= busy_int or (fdui.r.hold and not mult_valid);

    -- Fast writeback
    euo.alur <= alu_a_r(31 downto 0);

    -- SPRVAL...

    case fdui.r.drq.sra2(2 downto 0) is
      when "000" => ew.sprval := er.y;
      when "001" =>
        ew.sprval(7 downto 0) := er.psr(7 downto 0);
        ew.sprval(27 downto 8) := (others => '0');
        ew.sprval(31 downto 28) := er.psr(31 downto 28);
      when "010" =>
        ew.sprval(7 downto 0) := er.spsr(7 downto 0);
        ew.sprval(27 downto 8) := (others => '0');
        ew.sprval(31 downto 28) := er.spsr(31 downto 28);

      when "011" => ew.sprval := er.trapvector;  
      when "100" => ew.sprval := er.trappc;
      when "101" => ew.sprval := er.scratch;
      when others => ew.sprval := (others => 'X');
    end case;

    euo.sprval      <= ew.sprval;

    euo.imreg       <= fdui.r.drq.imreg;
    euo.sr          <= ew.sr;
    euo.cop         <= ci.data;

    -- Memory lines

    euo.sprwe     <= fdui.r.drq.sprwe;
    euo.mwreg     <= fdui.r.drq.sra2;
    euo.sr        <= fdui.r.drq.sr;
    euo.macc      <= fdui.r.drq.macc;
    euo.npc       <= fdui.r.drq.fpc;  -- NOTE: This is due to delay slot
    euo.data_write <= rhs; -- Memory always go through Alu2
    euo.data_address      <= std_logic_vector(reg_add_immed);
    euo.data_access       <= fdui.r.drq.memory_access;
    euo.data_writeenable  <= fdui.r.drq.memory_write;

    if fdui.valid='0' or passes_condition='0' then
      euo.data_access <= '0';
      euo.sprwe     <= '0';--fdui.r.drq.sprwe;

    end if;



    if rst='1' then
      ew.psr(0) := '1'; -- Supervisor
      ew.psr(31 downto 1) := (others =>'0'); -- Interrupts disabled
      ew.trapvector := RESETADDRESS;--others => '0');
      -- Debug.
      ew.trappc := fdui.r.drq.npc;
      ew.jump := '0';
      ew.regwe := '0';
      ew.valid := '0';
      ew.trapq := '0';
      ew.innmi := '0';
      euo.data_access <= '0';
    end if;

    if rising_edge(clk) then
      if invalid_instr then
        report "Invalid instruction" severity failure;
      end if;
      if trap then
        report "TRAP";
      end if;
      er <= ew;
    end if;
    -- synthesis translate_off
    dbg_do_interrupt <= do_interrupt;
    dbg_passes_condition <= passes_condition;
    -- synthesis translate_on
  end process;

  euo.jump <= (er.jump and fdui.valid) or (er.trapq);
  euo.trap <= do_trap;
  euo.clrhold <= mult_valid or (er.jump and fdui.valid) or (er.trapq) ;

end behave;
