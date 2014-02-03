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
    opcode:   in std_logic_vector(15 downto 0);
    dec:      out opdec_type
  );
end entity opdec;


architecture behave of opdec is

  signal decoded_op: decoded_opcode_type;
  signal mtype: memory_access_type;
  signal blocking: boolean;
begin

  -- Top level instruction decoder.
  process(opcode)
    variable op: decoded_opcode_type;
  begin
    case opcode(15 downto 12) is
      when "0000" =>
        blocking <= false;
        case opcode(11 downto 8) is
          when "0001" =>
            op := O_LSR;
          when "0010" =>
            op := O_SSR;
          when others =>
            op := O_NOP;
        end case;

      when "0001" =>
        -- ALU operations
        blocking <= false;
        case opcode(11 downto 8) is
          when "0000" => op := O_ADD;
          when "0001" => op := O_ADDC;
          when "0010" => op := O_SUB;
          when "0011" => op := O_SUBB;
          when "0100" => op := O_AND;
          when "0101" => op := O_OR;
          when "0110" => op := O_CMP;
          when "0111" => op := O_XOR;
          -- ALU B operations. These are the dual-reg
          -- operations.
          when "1000" => op := O_SHL;
          when "1001" => op := O_SRL;
          when "1010" => op := O_SRA;
          when "1011" => op := O_MUL;

          when "1100" => op := O_SHL;
          when "1101" => op := O_SRL;
          when "1110" => op := O_SRA;
          when "1111" => op := O_MUL;
          when others => null;
        end case;

      when "0010" =>
        blocking <= false;
        op := O_ST;

      when "0011" =>
        blocking <= false;
        -- NOT USED
        op := O_NOP;

      when "0100" =>
        blocking <= true; -- Not sure why....
        op := O_LD;

      when "0101" =>
        blocking <= false;
        -- NOT USED
        op := O_ADDRI;

      when "0110" =>
        blocking <= false;
        op := O_ADDI;

      when "0111" =>
        blocking <= true;
        -- NOT USED
        op := O_CMPI;

      when "1000" =>
        blocking <= false;
        op := O_IM;

      when "1001" =>
        blocking <= true;
        -- NOT USED
        op := O_BRI;

      when "1010" =>
        blocking <= true;
        case opcode(3 downto 0) is
          when "1000" => op := O_BRIE;
          when "1001" => op := O_BRINE;
          when "1010" => op := O_BRIG;
          when "1011" => op := O_BRIGE;
          when "1100" => op := O_BRIL;
          when "1101" => op := O_BRILE;
          when "1110" => op := O_BRIUG;
          when "1111" => op := O_BRIUGE;
          when "0001" => op := O_BRIUL;
          when "0010" => op := O_BRIULE;
          when others => op := O_BRIE;
        end case;

      when "1011" =>
        blocking <= true;
        op := O_BRR;

      when "1100" =>
        blocking <= true;
        op := O_CALLR;

      when "1101" =>
        blocking <= true;
        op := O_CALLI;

      when "1110" =>
        blocking <= false;
        op := O_LIMR;

      when "1111" =>
        blocking <= true;
        -- TODO: change this
        if opcode(11)='1' then
          op := O_RETX;
        else
          op := O_RET;
        end if;

      when others =>
        blocking <= true;
        op := O_NOP;

    end case;

    decoded_op <= op;

  end process;

  -- Decode memory access type, if applicable
  process(opcode)
  begin
    case opcode(10 downto 8) is
      when "000" => mtype <= M_WORD;
      when "001" => mtype <= M_HWORD;
      when "010" => mtype <= M_BYTE;
      when "011" => mtype <= M_SPR;

      when "100" => mtype <= M_WORD_POSTINC;
      when "101" => mtype <= M_HWORD_POSTINC;
      when "110" => mtype <= M_BYTE_POSTINC;
      when "111" => mtype <= M_SPR_POSTINC;
      when others =>
    end case;
  end process;


  process(opcode, decoded_op, mtype,blocking)
    -- synthesis translate_off
    variable targetstr: string(1 to 2);
    variable sourcestr: string(1 to 5);
    variable opstr: string(1 to 7);
    variable rnum:  string(1 to 1);
    -- synthesis translate_on
    variable d: opdec_type;
  begin
    --d := dec;
    d.opcode := opcode;
    d.sreg1 := opcode(3 downto 0);
    d.sreg2 := opcode(7 downto 4);
    d.sr := opcode(6 downto 4);

    d.dreg := d.sreg1;

    d.memory_access := '0';
    d.memory_write := 'X';
    d.rd1 := '0';
    d.rd2 := '0';
    d.except_return := false;

    -- synthesis translate_off
    dec.strasm <= opcode_txt_pad("UNKNOWN");
    -- synthesis translate_on

    -- Default values
    d.blocking    := true;
    d.modify_gpr  := false;
    d.uses        := uses_alu1;
    d.imm8        := opcode(11 downto 4);
    d.imm12       := opcode(11 downto 0);
    d.imm4        := opcode(11 downto 8);
    d.op          := decoded_op;
    d.macc        := mtype;
    d.reg_source  := reg_source_alu;
    d.modify_flags:= false;
    d.loadimm     := LOADNONE;
    d.jump_clause := JUMP_NONE;
    d.jump        := (others => 'X');
    d.alu2_imreg  := 'X';
    d.alu2_samereg:= '1';
    d.br_source   := br_source_none;
    d.modify_spr  := false;
    d.blocks      := '0';

    -- ALU operations are directly extracted from
    -- the opcode.

    -- TODO: this table is *wrong*.

    case opcode(10 downto 8) is
          when "000" =>
            d.alu1_op := ALU_ADD;
            d.alu2_op := ALU2_SHL;
          when "001" =>
            d.alu1_op := ALU_ADDC;
            d.alu2_op := ALU2_SRL;
          when "010" =>
            d.alu1_op := ALU_SUB;
            d.alu2_op := ALU2_SRA;
          when "011" =>
            d.alu1_op := ALU_SUBB;
            d.alu2_op := ALU2_MUL;
          when "100" =>
            d.alu1_op := ALU_AND;
            d.alu2_op := ALU2_SHL;
          when "101" =>
            d.alu1_op := ALU_OR;
            d.alu2_op := ALU2_SRL;
          when "110" =>
            d.alu1_op := ALU_SUB; -- CMP
            d.alu2_op := ALU2_SRA;
          when "111" =>
            d.alu1_op := ALU_XOR;
            d.alu2_op := ALU2_MUL;
          when others => null;
        end case;



    case decoded_op is

      when O_NOP =>
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("NOP ");
        -- synthesis translate_on
        d.uses := uses_nothing;
        d.blocking := true;
      when O_IM =>
        d.loadimm     := LOAD12;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("IM 0x" & hstr(d.imm12));
        -- synthesis translate_on
        d.blocking := false;
        d.uses := uses_nothing;

      when O_LIMR =>
        d.loadimm     := LOAD8;
        -- Load IMMediate into register target
        d.rd1:='0'; d.rd2:='0'; d.modify_gpr:=true; d.reg_source := reg_source_imm;
        d.blocking := false;
        d.uses := uses_nothing;

        -- synthesis translate_off
        d.strasm := opcode_txt_pad("LIMR 0x" & hstr(d.imm8) &", "& regname(d.dreg));
        -- synthesis translate_on
      when O_ADD =>
        --d.modify_flags := true;
        d.rd1:='1'; d.rd2:='1'; d.modify_gpr:=true; d.reg_source:=reg_source_alu;
        d.rd1:='1'; d.rd2:='1'; d.modify_gpr:=true; d.reg_source:=reg_source_alu;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("ADD " & regname(d.sreg2) & ", " & regname(d.dreg) );
        -- synthesis translate_on
        d.blocking := false;


      when O_ADDC =>
        --d.modify_flags := true;
        d.rd1:='1'; d.rd2:='1'; d.modify_gpr:=true; d.reg_source:=reg_source_alu;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("ADDC " & regname(d.sreg2) & ", " & regname(d.dreg) );
        -- synthesis translate_on
        d.blocking := false;

      when O_AND =>
        --d.modify_flags := true;
        d.rd1:='1'; d.rd2:='1'; d.modify_gpr:=true; d.reg_source:=reg_source_alu;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("AND " & regname(d.sreg2) & ", " & regname(d.dreg) );
        -- synthesis translate_on
        d.blocking := false;

      when O_OR =>
        --d.modify_flags := true;
        d.rd1:='1'; d.rd2:='1'; d.modify_gpr:=true; d.reg_source:=reg_source_alu;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("OR " & regname(d.sreg2) & ", " & regname(d.dreg) );
        -- synthesis translate_on
        d.blocking := false;

      when O_XOR =>
        --d.modify_flags := true;
        d.rd1:='1'; d.rd2:='1'; d.modify_gpr:=true; d.reg_source:=reg_source_alu;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("XOR " & regname(d.sreg2) & ", " & regname(d.dreg) );
        -- synthesis translate_on
        d.blocking := false;

      when O_SUB =>
        --d.modify_flags := true;
        d.rd1:='1'; d.rd2:='1'; d.modify_gpr:=true; d.reg_source:=reg_source_alu;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("SUB " & regname(d.sreg2) & ", " & regname(d.dreg) );
        -- synthesis translate_on
        d.blocking := false;

      when O_CMP =>
        d.modify_flags := true;
        d.rd1:='1'; d.rd2:='1'; d.modify_gpr:=false; d.reg_source:=reg_source_alu;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("CMP " & regname(d.sreg2) & ", " & regname(d.dreg) );
        -- synthesis translate_on
        d.blocking := false;

      when O_SUBB =>
        --d.modify_flags := true;
        d.rd1:='1'; d.rd2:='1'; d.modify_gpr:=true; d.reg_source:=reg_source_alu;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("SUBB " & regname(d.sreg2) & ", " & regname(d.dreg) );
        -- synthesis translate_on
        d.blocking := false;

      when O_NOT =>
        --d.modify_flags := true;
        d.uses := uses_alu2;
        d.rd1:='1'; d.rd2:='0'; d.modify_gpr:=true; d.reg_source:=reg_source_alu;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("NOT " & regname(d.dreg) );
        -- synthesis translate_on
        d.blocking := false;

      when O_SRA =>
        --d.modify_flags := true;
        d.uses := uses_alu2;
        d.rd1:='1'; d.rd2:='1'; d.modify_gpr:=true; d.reg_source:=reg_source_alu;
        --d.alu2_samereg := '0';
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("SRA " & regname(d.sreg2) & ", " &regname(d.dreg) );
        -- synthesis translate_on
        d.blocking := false;

      when O_SRL =>
        --d.modify_flags := true;
        d.uses := uses_alu2;
        d.rd1:='1'; d.rd2:='1'; d.modify_gpr:=true; d.reg_source:=reg_source_alu;
        --d.alu2_samereg := '0';
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("SRL " & regname(d.sreg2) & ", " &regname(d.dreg) );
        -- synthesis translate_on
        d.blocking := false;

      when O_SHL =>
        --d.modify_flags := true;
        d.uses := uses_alu2;
        d.rd1:='1'; d.rd2:='1'; d.modify_gpr:=true; d.reg_source:=reg_source_alu;
        --d.alu2_samereg:='0';
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("SHL " & regname(d.sreg2) &", "&regname(d.dreg) );
        -- synthesis translate_on
        d.blocking := false;

      when O_ADDI =>
        d.loadimm     := LOAD8;
        --d.modify_flags := true;
        d.alu2_imreg := '1';
        d.alu2_op := ALU2_ADD;

        d.rd1:='1'; d.rd2:='0'; d.modify_gpr:=true; d.reg_source:=reg_source_alu;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("ADDI " & regname(d.sreg1) & ", " & hstr(d.imm8) );
        -- synthesis translate_on
        d.blocking := false;
        d.uses := uses_alu2;

      when O_ADDRI =>
        d.loadimm     := LOAD0;
        --d.modify_flags := false; -- This should be eventually true.
        d.alu2_imreg := '1';
        d.alu2_op := ALU2_ADD;
        d.alu2_samereg:='0';

        d.rd1:='1'; d.rd2:='1'; d.modify_gpr:=true; d.reg_source:=reg_source_alu;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("ADDRI " & regname(d.sreg2) & ", " & regname(d.dreg) );
        -- synthesis translate_on
        d.blocking := false;
        d.uses := uses_alu2;

      when O_CMPI =>
        d.loadimm     := LOAD8;
        d.modify_flags := true;
        d.rd1:='1'; d.rd2:='0'; d.modify_gpr:=false; d.reg_source:=reg_source_alu;
        d.alu2_imreg:='1';
        d.alu2_op := ALU2_CMPI;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("CMPI " & regname(d.sreg1) & ", " & hstr(d.imm8) );
        -- synthesis translate_on
        d.uses := uses_alu2;
        d.blocking := true;

      when O_BRR =>
        d.rd1:='1'; d.rd2:='0'; d.modify_gpr:=false; d.reg_source:=reg_source_alu;
        d.alu2_imreg:='1';
        d.blocking := true;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRR " & regname(d.sreg1) & " + " & hstr(d.imm8) );
        -- synthesis translate_on

      when O_CALLR =>
        d.rd1:='1'; d.rd2:='0'; d.modify_gpr:=false; d.reg_source:=reg_source_alu;
        d.alu2_imreg:='1';
        d.br_source := br_source_pc;
        d.jump_clause := JUMP_INCONDITIONAL;
        d.jump := JUMP_RI_PCREL;
        d.blocking := true;

        -- synthesis translate_off
        d.strasm := opcode_txt_pad("CALLR " & regname(d.sreg1) & " + " & hstr(d.imm8) );
        -- synthesis translate_on

      when O_ST =>
        d.alu2_op := ALU2_ADD;
        d.memory_access := '1';
        d.memory_write := '1';
        d.blocking := false;

        d.rd1:='1'; d.rd2:='1';
        d.alu2_imreg :='1';
        d.uses := uses_alu2;
        d.loadimm := LOAD0;

        case mtype is

          when M_WORD =>
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STW " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_WORD_POSTINC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STW+ " & regname(d.sreg2) & ", [" & regname(d.dreg) & "++]" );
            -- synthesis translate_on
          when M_HWORD =>
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STS " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_HWORD_POSTINC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STS+ " & regname(d.sreg2) & ", [" & regname(d.dreg) & "++]" );
            -- synthesis translate_on
          when M_BYTE =>
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STB " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_BYTE_POSTINC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STB+ " & regname(d.sreg2) & ", [" & regname(d.dreg) & "++]" );
            -- synthesis translate_on
          when M_SPR =>
            d.reg_source:=reg_source_alu;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STSPR " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_SPR_POSTINC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STSPR+ " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when others =>
        end case;


      when O_LD =>
        d.alu2_op := ALU2_ADD;
        d.memory_access := '1';
        d.memory_write := '0';
        d.rd1:='1'; d.rd2:='0';
        d.alu2_imreg :='1';
        d.uses := uses_alu2;
        d.loadimm := LOAD0;
        d.blocking := true;
        d.blocks := '1';

        case mtype is

          when M_WORD =>
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("LD " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_WORD_POSTINC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("LD " & regname(d.sreg2) & ", [" & regname(d.dreg) & "++]" );
            -- synthesis translate_on
          when M_HWORD =>
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("LDS " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_HWORD_POSTINC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("LDS+ " & regname(d.sreg2) & ", [" & regname(d.dreg) & "++]" );
            -- synthesis translate_on
          when M_BYTE =>
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("LDB " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_BYTE_POSTINC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("LDB+ " & regname(d.sreg2) & ", [" & regname(d.dreg) & "++]" );
            -- synthesis translate_on
          when M_SPR =>
            d.modify_spr := true;
            d.blocks := '0'; -- Withtout this it taints invalid registers.

            -- synthesis translate_off
            d.strasm := opcode_txt_pad("LDSPR " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_SPR_POSTINC =>
            d.modify_spr := true;
            d.blocks := '0'; -- Withtout this it taints invalid registers.
            d.modify_gpr:=true; d.reg_source:=reg_source_alu;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("LDSPR+ " & regname(d.sreg2) & ", [" & regname(d.dreg) & "++]" );
            -- synthesis translate_on
          when others =>
        end case;

      when O_BRI =>
        d.loadimm := LOAD8;
        d.jump_clause := JUMP_INCONDITIONAL;
        d.jump := JUMP_I_PCREL;
        d.blocking := true;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRI 0x" & hstr(d.imm8));
        -- synthesis translate_on
      when O_BRIE =>
        d.loadimm := LOAD8;
        d.jump_clause := JUMP_E;
        d.jump := JUMP_I_PCREL;
        d.blocking := true;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRIE 0x" & hstr(d.imm8));
        -- synthesis translate_on
      when O_BRINE =>
        d.loadimm := LOAD8;
        d.jump_clause := JUMP_NE;
        d.jump := JUMP_I_PCREL;
        d.blocking := true;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRINE 0x" & hstr(d.imm8));
        -- synthesis translate_on
      when O_BRIG =>
        d.jump_clause := JUMP_G;
        d.jump := JUMP_I_PCREL;
        d.loadimm := LOAD8;
        d.blocking := true;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRIG 0x" & hstr(d.imm8));
        -- synthesis translate_on
      when O_BRIGE =>
        d.jump_clause := JUMP_GE;
        d.jump := JUMP_I_PCREL;
        d.loadimm := LOAD8;
        d.blocking := true;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRIGE 0x" & hstr(d.imm8));
        -- synthesis translate_on
      when O_BRIL =>
        d.loadimm := LOAD8;
        d.jump_clause := JUMP_L;
        d.jump := JUMP_I_PCREL;
        d.blocking := true;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRIL 0x" & hstr(d.imm8));
        -- synthesis translate_on
      when O_BRILE =>
        d.loadimm := LOAD8;
        d.jump_clause := JUMP_LE;
        d.jump := JUMP_I_PCREL;
        d.blocking := true;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRILE 0x" & hstr(d.imm8));
        -- synthesis translate_on
      when O_BRIUG =>
        d.jump_clause := JUMP_UG;
        d.jump := JUMP_I_PCREL;
        d.loadimm := LOAD8;
        d.blocking := true;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRIUG 0x" & hstr(d.imm8));
        -- synthesis translate_on
      when O_BRIUGE =>
        d.jump_clause := JUMP_UGE;
        d.jump := JUMP_I_PCREL;
        d.loadimm := LOAD8;
        d.blocking := true;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRIUGE 0x" & hstr(d.imm8));
        -- synthesis translate_on
      when O_BRIUL =>
        d.loadimm := LOAD8;
        d.jump_clause := JUMP_UL;
        d.jump := JUMP_I_PCREL;
        d.blocking := true;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRIUL 0x" & hstr(d.imm8));
        -- synthesis translate_on
      when O_BRIULE =>
        d.loadimm := LOAD8;
        d.jump_clause := JUMP_ULE;
        d.jump := JUMP_I_PCREL;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRIULE 0x" & hstr(d.imm8));
        -- synthesis translate_on
        d.blocking := true;

      when O_RET =>
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("RET ");
        -- synthesis translate_on
        d.jump_clause := JUMP_INCONDITIONAL;
        d.jump := JUMP_BR_ABS;
        d.blocking := true;
      when O_RETX =>
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("RETX ");
        -- synthesis translate_on
        d.jump_clause := JUMP_INCONDITIONAL;
        d.jump := JUMP_BR_ABS;
        d.except_return := true;
        d.blocking := true;


      when O_CALLI =>
        d.rd1:='1'; d.rd2:='0';
        d.alu2_op:=ALU2_ADD;
        d.modify_gpr:=false; d.reg_source:=reg_source_alu;
        d.loadimm := LOAD8;
        d.br_source := br_source_pc;
        d.jump_clause := JUMP_INCONDITIONAL;
        d.jump := JUMP_I_PCREL;
        d.blocking := true;

        -- synthesis translate_off
        d.strasm := opcode_txt_pad("CALLI 0x" & hstr(d.imm8));
        -- synthesis translate_on

      when O_LSR =>
        d.modify_gpr:=true; d.reg_source:=reg_source_spr;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("LSR ");
        -- synthesis translate_on
        d.blocking := false;

      when O_SSR =>
        d.rd1:='1';
        d.modify_spr := true;
        if d.sreg1(2 downto 0)="001" then
          d.br_source := br_source_reg;
        end if;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("SSR ");
        -- synthesis translate_on

      when others =>
        d.blocking := true;

        -- synthesis translate_off
        d.strasm      := opcode_txt_pad("U " & hstr(opcode));
        -- synthesis translate_on
    end case;

    -- Attempt.
    d.blocking := blocking;
    dec <= d;

  end process;


end behave;
