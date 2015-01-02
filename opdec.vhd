library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.xtcpkg.all;
-- synthesis translate_off
use work.txt_util.all;
-- synthesis translate_on

entity opdec is
  port (
    opcode_high:  in std_logic_vector(15 downto 0);
    opcode_low:   in std_logic_vector(15 downto 0);
    dec:          out opdec_type
  );
end entity opdec;


architecture behave of opdec is

--  signal decoded_op: decoded_opcode_type;
--  signal mtype: memory_access_type;
  --signal opcode: std_logic_vector(15 downto 0);
  --signal is_extended_opcode: boolean;

  function loadimm2str(i: in loadimmtype) return string is
    variable r: string(1 to 2);
  begin
    case i is
      when LOADNONE => r:= "N ";
      when LOAD8    => r:= "8 ";
      when LOAD16   => r:= "16";
      when LOAD24   => r:= "24";
      when LOAD0    => r:= "0 ";
      when others   => r:= "??";
    end case;
    return r;
  end function;

begin

  -- Insn opcode depends on whether we have an extention opcode or
  -- not.

  process(opcode_low, opcode_high)
    -- synthesis translate_off
    variable targetstr: string(1 to 2);
    variable sourcestr: string(1 to 5);
    variable opstr: string(1 to 7);
    variable rnum:  string(1 to 1);
    -- synthesis translate_on
    variable d: opdec_type;
    variable subloadimm: loadimmtype;
    --variable subloadimm2: loadimmtype;
    variable op: decoded_opcode_type;
    variable force_flags: boolean;
    variable mtype: memory_access_type;
    variable opcode: std_logic_vector(15 downto 0);
    variable is_extended_opcode: boolean;

  begin

    if opcode_high(15)='1' then
      is_extended_opcode := true;
    else
      is_extended_opcode := false;
    end if;

    opcode := opcode_high;


  -- Decode memory access type, if applicable
    case opcode(10 downto 8) is
      when "000" => mtype := M_WORD;
      when "001" => mtype := M_HWORD;
      when "010" => mtype := M_BYTE;
      when "011" => mtype := M_SPR;

      when "100" => mtype := M_WORD_POSTINC;
      when "101" => mtype := M_HWORD_POSTINC;
      when "110" => mtype := M_BYTE_POSTINC;
      when "111" => mtype := M_SPR_POSTINC;
      when others =>
    end case;
    
    case opcode(14 downto 12) is
      when "000" => -- ALU
        op := O_ALU;

      when "001" =>
        -- Memory instructions.
        case opcode(11) is
          when '0' => op := O_ST;
          when '1' => op := O_LD;
          when others =>
        end case;

      when "010" =>
        -- Cop instructions
        case opcode(11) is
          when '0' =>
            case opcode(10) is
              when '0' => op := O_COPR;
              when '1' => op := O_COPW;
              when others =>
            end case;
          when '1' =>
            op := O_SWI;
          when others =>
        end case;
      when "011" =>
        -- Single R/NoR.
        case opcode(11) is
          when '0' =>
            -- Single R
            case opcode(10) is
              when '0' => op := O_JMP;
              when '1' => op := O_JMPE;
              when others =>
            end case;
          when '1' =>
            -- No/R
            case opcode(10) is
            when '0' =>
              case opcode(9) is
                when '0' => op := O_SEXTB;      -- 38
                when '1' => op := O_SEXTS;      -- 3a
                when others =>
              end case;
            when '1' =>
              case opcode(9) is
                when '0' => op := O_RSPR;      -- 38
                when '1' => op := O_WSPR;      -- 3a
                when others =>
              end case;

            when others =>
            end case;
            --op := O_ABORT;
          when others =>
            op := O_ABORT;
        end case;

      when "100" =>
        op := O_BR;
      when "101" =>
        op := O_ADDI;
      when "110" =>
        op := O_CMPI;
      when "111" =>
        op := O_LIMR;

      when others =>

    end case;

    -- Special case op.
    if is_extended_opcode then
      if opcode_low(14 downto 13)="11" then
        op := O_IM;
      end if;
    end if;

    --decoded_op := op;

    d.opcode := opcode;
    d.sreg1 := opcode(3 downto 0);
    d.sreg2 := opcode(7 downto 4);
    d.sr := opcode(6 downto 4);

    d.dreg := d.sreg1;

    d.memory_access := '0';
    d.memory_write := 'X';
    d.alu_source := alu_source_reg;
    d.rd1 := '0';
    d.rd2 := '0';
    d.except_return := false;

    subloadimm := LOADNONE;
    force_flags:=false;

    -- Default values
    d.modify_gpr  := false;
    d.op          := op;
    d.macc        := mtype;
    d.reg_source  := reg_source_alu;
    d.modify_flags:= false;
    d.loadimm     := LOADNONE;
    d.is_jump     := false;
    d.jump        := (others => 'X');
    d.modify_spr  := false;
    d.blocks      := '0';
    d.condition   := CONDITION_UNCONDITIONAL;
    d.imflag      := '0';
    d.enable_alu  := '0';
    d.use_carry   := '0';
    d.cop_en      := '0';
    d.cop_wr      := 'X';

    d.cop_id      := opcode(9 downto 8);
    d.cop_reg     := opcode(7 downto 4);

    d.priv        := '0';
    d.ismult      := '0';
    -- ALU operations are directly extracted from
    -- the opcode.

    case opcode(11 downto 8) is
      when "0000" =>
        d.alu_op := ALU_ADD;
      when "0001" =>
        d.alu_op := ALU_ADDC;
      when "0010" =>
        d.alu_op := ALU_SUB;
      when "0011" =>
        d.alu_op := ALU_SUBB;
      when "0100" =>
        d.alu_op := ALU_AND;
      when "0101" =>
        d.alu_op := ALU_OR;
      when "0110" =>
        d.alu_op := ALU_XOR;
      when "0111" =>
        d.alu_op := ALU_CMP;

      when "1000" =>
        d.alu_op := ALU_SHL;
      when "1001" =>
        d.alu_op := ALU_SRL;
      when "1010" =>
        d.alu_op := ALU_SRA;
      when "1011" =>
        d.alu_op := ALU_MUL;
      when "1100" =>
        d.alu_op := ALU_ADDRI;
      when "1101" =>
        d.alu_op := ALU_NOT;
      when "1110" =>
        d.alu_op := ALU_ADD;--ALU_SEXTB;
        force_flags:= true;
      when "1111" =>
        d.alu_op := ALU_SUB;--ALU_SEXTS;
        force_flags:=true;


      when others => null;
    end case;




        


    case op is

      when O_IM =>
        subloadimm := LOAD24;
        
      when O_NOP =>
      when O_LIMR =>
        subloadimm     := LOAD8;
        -- Load IMMediate into register target
        d.rd1:='1'; d.rd2:='0'; d.modify_gpr:=true; d.reg_source := reg_source_alu;
        d.alu_source := alu_source_immed;
        d.sreg1 := (others => '0');
        d.alu_op := ALU_ADD;
        --if opcode(3 downto 0)="000" then
          -- Target is IMMed.
          -- TODO
        --  d.imflag := '1';
        --end if;

      when O_ALU =>
        d.modify_gpr:=true; 

        if d.alu_op=ALU_CMP then
          d.modify_flags := true;
          d.modify_gpr := false;
          d.alu_op := ALU_SUB;
        end if;

        if force_flags then
          d.modify_flags := true;
        end if;

        if d.alu_op=ALU_ADDRI then
          d.alu_source := alu_source_immed;
          d.sreg1 := opcode(7 downto 4);
          --d.sreg2 := opcode(3 downto 0);
          d.alu_op := ALU_ADD;
        end if;

        d.use_carry := '0';

        if d.alu_op=ALU_ADDC then
          d.use_carry := '1';
          d.alu_op := ALU_ADD;
        end if;

        if d.alu_op=ALU_SUBB then
          d.use_carry := '1';
          d.alu_op := ALU_SUB;
        end if;
        if d.alu_op=ALU_MUL then
          d.ismult := '1';
        end if;

        d.rd1:='1'; d.rd2:='1';
        d.reg_source:=reg_source_alu;

        d.enable_alu := '1';

      when O_ADDI =>
        subloadimm     := LOAD8;
        d.alu_source := alu_source_immed;
        d.alu_op := ALU_ADD;
        d.rd1:='1'; d.rd2:='0'; d.modify_gpr:=true; d.reg_source:=reg_source_alu;
        d.enable_alu := '1';

      when O_ADDRI =>
        --subloadimm     := LOAD0;
        -- Swap register...
        --d.sreg1 := opcode(7 downto 4);

        d.alu_op := ALU_ADD;
        d.alu_source := alu_source_immed;
        d.rd1:='1'; d.rd2:='1'; d.modify_gpr:=true; d.reg_source:=reg_source_alu;
        d.enable_alu := '1';

      when O_CMPI =>
        subloadimm     := LOAD8;
        d.modify_flags := true;
        d.alu_source := alu_source_immed;
        d.alu_op := ALU_SUB;
        d.rd1:='1'; d.rd2:='0'; d.modify_gpr:=false; d.reg_source:=reg_source_alu;
        d.enable_alu := '1';
        --d.alu2_imreg:='1';
        --d.alu2_op := ALU2_CMPI;
        --d.uses := uses_alu2;
        --d.blocking := true;

      when O_BR =>
        subloadimm := LOAD8;
        d.rd1:='0'; d.rd2:='0'; d.modify_gpr:=true; d.reg_source:=reg_source_pcnext;
        d.is_jump := true;
        d.jump := JUMP_I_PCREL;

      when O_JMP =>
        -- Swap register...
        d.sreg1 := opcode(7 downto 4);
        d.rd1:='1'; d.rd2:='0'; d.modify_gpr:=true; d.reg_source:=reg_source_pcnext;
        d.is_jump := true;
        d.jump := JUMP_RI_ABS;

      when O_JMPE =>
        -- Swap register...
        d.sreg1 := opcode(7 downto 4);
        d.rd1:='0'; d.rd2:='0'; d.modify_gpr:=false;
        d.is_jump := true;
        d.jump := JUMP_RI_ABS;
        d.except_return:=true;

      when O_COPR =>
        d.cop_en := '1';
        d.cop_wr := '0';
        d.priv   := '1';
        d.rd1:='0'; d.rd2:='0'; d.modify_gpr:=true; d.reg_source:=reg_source_cop;

      when O_COPW =>
        d.cop_en := '1';
        d.priv   := '1';
        d.cop_wr := '1';
        d.rd1:='1'; d.rd2:='0'; d.modify_gpr:=true; d.reg_source:=reg_source_cop;

      when O_ST =>
        d.memory_access := '1';
        d.memory_write := '1';
        d.rd1:='1'; d.rd2:='1';
        d.loadimm := LOAD0;

      when O_LD =>
        -- Swap register
        --d.sreg1 := opcode(7 downto 4);
        d.memory_access := '1';
        d.memory_write := '0';
        d.rd1:='1'; d.rd2:='1';
        d.blocks := '1';

      when O_SEXTB =>
        d.alu_source := alu_source_reg;
        d.alu_op := ALU_SEXTB;
        d.rd1:='1'; d.rd2:='0'; d.modify_gpr:=true; d.reg_source:=reg_source_alu;
        d.enable_alu := '1';
          d.sreg1 := opcode(7 downto 4);

      when O_SEXTS =>
        d.alu_source := alu_source_reg;
        d.alu_op := ALU_SEXTS;
        d.rd1:='1'; d.rd2:='0'; d.modify_gpr:=true; d.reg_source:=reg_source_alu;
        d.enable_alu := '1';
          d.sreg1 := opcode(7 downto 4);

      when O_RSPR =>
        --d.alu_source := alu_source_;
        --d.alu_op := ALU_SEXTB;
        d.rd1:='1'; d.rd2:='0'; d.modify_gpr:=true; d.reg_source:=reg_source_spr;
        d.enable_alu := '1';
        d.priv := '1';

      when O_WSPR =>
        --d.alu_source := alu_source_;
        --d.alu_op := ALU_SEXTB;
        d.modify_spr:=true;
        d.rd1:='1'; d.rd2:='0'; d.modify_gpr:=false;
        d.enable_alu := '1';
        d.priv := '1';

      when O_SWI =>
        

      when others =>
    end case;

      --- HAAAAACK
    --  if opcode=x"0000" then
--        op:= O_SWI;
--      end if;

    -- This is current version, and works.

    d.imm8l(7 downto 0) := opcode(11 downto 4);
    d.imm8h(7 downto 0) := opcode_low(7 downto 0);
    d.imm24 := opcode_low(12) & opcode_low(7 downto 0) & opcode_high(14 downto 0);

    -- This is more optimized. Requires lots of compiler changes.

    --d.imm8l(7 downto 0) := opcode_high(11 downto 4);
    --d.imm8h(7 downto 0) := opcode_low(7 downto 0);
    --d.imm24 := opcode_low(12) & opcode_high(14 downto 12) & opcode_high(3 downto 0) &
    --  opcode_low(7 downto 0) & opcode_high(11 downto 4);



    if is_extended_opcode then
      case subloadimm is
        when LOAD8 =>

          case opcode_low(14 downto 13) is
            when "10" =>
              d.loadimm := LOAD16;
            when others =>
              d.loadimm := LOAD8;
          end case;

        when LOAD24 =>
          d.loadimm := LOAD24;
          d.imflag := '1';
        
        when others =>
          case opcode_low(14 downto 13) is
            when "10" =>
              -- 8L is from upper word.
              d.imm8l := d.imm8h;
              d.loadimm := LOAD8;
            when others =>

            d.loadimm := LOADNONE;
          end case;
      end case;
    else
      d.loadimm := subloadimm;

    end if;

    d.extended := is_extended_opcode;
  
    -- Condition codes.
    if (is_extended_opcode) then
      case opcode_low(11 downto 8) is
        when "0000" => d.condition := CONDITION_UNCONDITIONAL;
        when "0001" => d.condition := CONDITION_NE;
        when "0010" => d.condition := CONDITION_E;
        when "0011" => d.condition := CONDITION_G;
        when "0100" => d.condition := CONDITION_GE;
        when "0101" => d.condition := CONDITION_L;
        when "0110" => d.condition := CONDITION_LE;
        when "0111" => d.condition := CONDITION_UG;
        when "1000" => d.condition := CONDITION_UGE;
        when "1001" => d.condition := CONDITION_UL;
        when "1010" => d.condition := CONDITION_ULE;
        when "1011" => d.condition := CONDITION_S;
        when "1100" => d.condition := CONDITION_NS;
        when others => d.condition := CONDITION_UNCONDITIONAL;
      end case;
      -- Check DREG
      if opcode_low(14 downto 12)="010" then
        -- DREG extended....
        d.dreg := opcode_low(3 downto 0);
      end if;

      if op=O_ALU and opcode_low(14 downto 12)="100" then
        d.alu_source := alu_source_immed;
        d.sreg1 := opcode(7 downto 4);
      end if;
    end if;

    d.targetzero:='0';
    if d.dreg="0000" then
      d.targetzero:='1';
    end if;

    dec <= d;

  end process;


end behave;
