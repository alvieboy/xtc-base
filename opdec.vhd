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

begin

  -- Top level instruction decoder.
  process(opcode)
    variable op: decoded_opcode_type;
  begin
    case opcode(15 downto 12) is
      when "0000" =>
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
        case opcode(11 downto 9) is
          when "000" => op := O_ADD;
          when "001" => op := O_ADDC;
          when "010" => op := O_SUB;
          --when "011" => op := O_SUBC;
          when "100" => op := O_AND;
          when "101" => op := O_OR;
          when "110" => op := O_COPY;
          when others => op := O_NOP;
        end case;

      when "0010" =>
        op := O_ST;

      when "0011" =>
        -- NOT USED
        op := O_NOP;

      when "0100" =>
        op := O_LD;

      when "0101" =>
        -- NOT USED
        op := O_NOP;

      when "0110" =>
        op := O_ADDI;

      when "0111" =>
        -- NOT USED
        op := O_CMPI;

      when "1000" =>
        op := O_IM;

      when "1001" =>
        -- NOT USED
        op := O_NOP;

      when "1010" =>
        if opcode(3)='0' then
          op := O_BRI;
        else
          case opcode(2 downto 0) is
            when "000" => op := O_BRIE;
            when "001" => op := O_BRINE;
            when "010" => op := O_BRIG;
            when "011" => op := O_BRIGE;
            when "100" => op := O_BRIL;
            when "101" => op := O_BRILE;
            when others => op := O_NOP;
          end case;
        end if;

      when "1011" =>
        op := O_BRR;

      when "1100" =>
        op := O_CALLR;
      when "1101" =>
        op := O_CALLI;

      when "1110" =>
        op := O_LIMR;

      when "1111" =>
        -- TODO: change this
        op := O_RET;

      when others =>
        op := O_NOP;

    end case;

    decoded_op <= op;

  end process;

  -- Decode memory access type, if applicable
  process(opcode)
  begin
    case opcode(11 downto 8) is
      when "0000" => mtype <= M_WORD;
      when "0001" => mtype <= M_WORD_PREINC;
      when "0010" => mtype <= M_WORD_POSTINC;
      when "0011" => mtype <= M_WORD_PREDEC;
      when "0100" => mtype <= M_WORD_POSTDEC;
      when "0101" => mtype <= M_HWORD;
      when "0110" => mtype <= M_HWORD_PREINC;
      when "0111" => mtype <= M_HWORD_POSTINC;
      when "1000" => mtype <= M_BYTE;
      when "1001" => mtype <= M_BYTE_PREINC;
      when "1010" => mtype <= M_BYTE_POSTINC;
      when "1011" => mtype <= M_WORD_IND;
      when "1100" => mtype <= M_HWORD_IND;
      when "1101" => mtype <= M_BYTE_IND;
      when others => mtype <= M_WORD;
    end case;
  end process;


  process(opcode, decoded_op, mtype)
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

    -- synthesis translate_off
    dec.strasm <= opcode_txt_pad("UNKNOWN");
    -- synthesis translate_on

    -- Default values
    d.blocking    := true;
    d.modify_gpr  := false;
    d.uses        := uses_alu1;
    d.alu2_op     := ALU_UNKNOWN;
    d.alu1_op     := ALU_UNKNOWN;
    d.imm8        := opcode(11 downto 4);
    d.imm12       := opcode(11 downto 0);
    d.imm4        := opcode(11 downto 8);
    d.op          := decoded_op;
    d.macc        := mtype;
    d.reg_source  := reg_source_alu1;
    d.modify_flags:= false;
    d.loadimm     := LOADNONE;

    case decoded_op is

      when O_NOP =>
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("NOP ");
        -- synthesis translate_on
      when O_IM =>
        d.loadimm     := LOAD12;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("IM 0x" & hstr(d.imm12));
        -- synthesis translate_on

      when O_LIMR =>
        d.loadimm     := LOAD8;
        -- Load IMMediate into register target
        d.rd1:='0'; d.rd2:='0'; d.modify_gpr:=true; d.reg_source := reg_source_imm;
        

        -- synthesis translate_off
        d.strasm := opcode_txt_pad("LIMR 0x" & hstr(d.imm8) &", "& regname(d.dreg));
        -- synthesis translate_on
      when O_ADD =>
        d.modify_flags := true;
        d.rd1:='1'; d.rd2:='1'; d.alu1_op:=ALU_ADD; d.modify_gpr:=true; d.reg_source:=reg_source_alu1;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("ADD " & regname(d.sreg1) & ", " & regname(d.sreg2) );
        -- synthesis translate_on

      when O_ADDC =>
        d.modify_flags := true;
        d.rd1:='1'; d.rd2:='1'; d.alu1_op:=ALU_ADDC; d.modify_gpr:=true; d.reg_source:=reg_source_alu1;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("ADDC " & regname(d.sreg1) & ", " & regname(d.sreg2) );
        -- synthesis translate_on

      when O_AND =>
        d.modify_flags := true;
        d.rd1:='1'; d.rd2:='1'; d.alu1_op:=ALU_AND; d.modify_gpr:=true; d.reg_source:=reg_source_alu1;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("AND " & regname(d.sreg1) & ", " & regname(d.sreg2) );
        -- synthesis translate_on

      when O_OR =>
        d.modify_flags := true;
        d.rd1:='1'; d.rd2:='1'; d.alu1_op:=ALU_OR; d.modify_gpr:=true; d.reg_source:=reg_source_alu1;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("OR " & regname(d.sreg1) & ", " & regname(d.sreg2) );
        -- synthesis translate_on

      when O_SUB =>
        d.modify_flags := true;
        d.rd1:='1'; d.rd2:='1'; d.alu1_op:=ALU_SUB; d.modify_gpr:=true; d.reg_source:=reg_source_alu1;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("SUB " & regname(d.sreg1) & ", " & regname(d.sreg2) );
        -- synthesis translate_on

      when O_COPY =>
        d.modify_flags := false;
        d.rd1:='1'; d.rd2:='1'; d.alu1_op:=ALU_COPY; d.modify_gpr:=true; d.reg_source:=reg_source_alu1;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("COPY " & regname(d.sreg1) & ", " & regname(d.sreg2) );
        -- synthesis translate_on

      when O_ADDI =>
        d.loadimm     := LOAD8;
        d.modify_flags := true;
        d.rd1:='1'; d.rd2:='0'; d.alu2_op:=ALU_ADD; d.modify_gpr:=true; d.reg_source:=reg_source_alu2;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("ADDI " & regname(d.sreg1) & ", " & hstr(d.imm8) );
        -- synthesis translate_on

      when O_CMPI =>
        d.loadimm     := LOAD8;
        d.modify_flags := true;
        d.rd1:='1'; d.rd2:='0'; d.alu2_op:=ALU_CMPI; d.modify_gpr:=false; d.reg_source:=reg_source_alu2;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("CMPI " & regname(d.sreg1) & ", " & hstr(d.imm8) );
        -- synthesis translate_on

      when O_BRR =>
        d.rd1:='1'; d.rd2:='0'; d.alu2_op:=ALU_ADD; d.modify_gpr:=false; d.reg_source:=reg_source_alu2;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRR " & regname(d.sreg1) & " + " & hstr(d.imm8) );
        -- synthesis translate_on

      when O_CALLR =>
        d.rd1:='1'; d.rd2:='0'; d.alu2_op:=ALU_ADD; d.modify_gpr:=false; d.reg_source:=reg_source_alu2;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("CALLR " & regname(d.sreg1) & " + " & hstr(d.imm8) );
        -- synthesis translate_on

      when O_ST =>
        d.alu2_op := ALU_ADD; 
        d.memory_access := '1';
        d.memory_write := '1';
        d.rd1:='1'; d.rd2:='1';
        case mtype is

          when M_WORD =>
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STW " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_WORD_PREINC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu2;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("ST+W " & regname(d.sreg2) & ", [++" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_WORD_PREDEC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu2;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("ST-W " & regname(d.sreg2) & ", [--" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_WORD_POSTINC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu2;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STW+ " & regname(d.sreg2) & ", [" & regname(d.dreg) & "++]" );
            -- synthesis translate_on
          when M_WORD_POSTDEC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu2;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STW- " & regname(d.sreg2) & ", [" & regname(d.dreg) & "--]" );
            -- synthesis translate_on
          when M_HWORD =>
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STS " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_HWORD_POSTINC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu2;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STS+ " & regname(d.sreg2) & ", [" & regname(d.dreg) & "++]" );
            -- synthesis translate_on
          when M_HWORD_PREINC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu2;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("ST+S " & regname(d.sreg2) & ", [++" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_BYTE =>
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STB " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_BYTE_POSTINC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu2;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STB+ " & regname(d.sreg2) & ", [" & regname(d.dreg) & "++]" );
            -- synthesis translate_on
          when M_BYTE_PREINC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu2;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("ST+B " & regname(d.sreg2) & ", [++" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_WORD_IND =>
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STI " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_HWORD_IND =>
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STSI " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_BYTE_IND =>
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STBI " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when others =>
        end case;


      when O_LD =>
        d.alu2_op := ALU_ADD; 
        d.memory_access := '1';
        d.memory_write := '0';
        d.rd1:='1'; d.rd2:='1';
        case mtype is

          when M_WORD =>
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("LD " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_WORD_PREINC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu2;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("LD " & regname(d.sreg2) & ", [++" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_WORD_PREDEC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu2;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("LD " & regname(d.sreg2) & ", [--" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_WORD_POSTINC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu2;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("LD " & regname(d.sreg2) & ", [" & regname(d.dreg) & "++]" );
            -- synthesis translate_on
          when M_WORD_POSTDEC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu2;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("LD " & regname(d.sreg2) & ", [" & regname(d.dreg) & "--]" );
            -- synthesis translate_on
          when M_HWORD =>
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STS " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_HWORD_POSTINC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu2;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STS " & regname(d.sreg2) & ", [" & regname(d.dreg) & "++]" );
            -- synthesis translate_on
          when M_HWORD_PREINC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu2;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STS " & regname(d.sreg2) & ", [++" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_BYTE =>
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STB " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_BYTE_POSTINC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu2;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STB " & regname(d.sreg2) & ", [" & regname(d.dreg) & "++]" );
            -- synthesis translate_on
          when M_BYTE_PREINC =>
            d.modify_gpr:=true; d.reg_source:=reg_source_alu2;
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STB " & regname(d.sreg2) & ", [++" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_WORD_IND =>
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STI " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_HWORD_IND =>
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STSI " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when M_BYTE_IND =>
            -- synthesis translate_off
            d.strasm := opcode_txt_pad("STBI " & regname(d.sreg2) & ", [" & regname(d.dreg) & "]" );
            -- synthesis translate_on
          when others =>
        end case;

      when O_BRI =>
        d.loadimm := LOAD8;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRI 0x" & hstr(d.imm8));
        -- synthesis translate_on
      when O_BRIE =>
        d.loadimm := LOAD8;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRIE 0x" & hstr(d.imm8));
        -- synthesis translate_on
      when O_BRINE =>
        d.loadimm := LOAD8;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRINE 0x" & hstr(d.imm8));
        -- synthesis translate_on
      when O_BRIG =>
        d.loadimm := LOAD8;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRIG 0x" & hstr(d.imm8));
        -- synthesis translate_on
      when O_BRIGE =>
        d.loadimm := LOAD8;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRIGE 0x" & hstr(d.imm8));
        -- synthesis translate_on
      when O_BRIL =>
        d.loadimm := LOAD8;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRIL 0x" & hstr(d.imm8));
        -- synthesis translate_on
      when O_BRILE =>
        d.loadimm := LOAD8;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("BRILE 0x" & hstr(d.imm8));
        -- synthesis translate_on

      when O_RET =>
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("RET ");
        -- synthesis translate_on

      when O_CALLI =>
        d.rd1:='1'; d.rd2:='0'; d.alu2_op:=ALU_ADD; d.modify_gpr:=false; d.reg_source:=reg_source_alu2;
        d.loadimm := LOAD8;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("CALLI 0x" & hstr(d.imm8));
        -- synthesis translate_on

      when O_LSR =>
        d.modify_gpr:=true; d.reg_source:=reg_source_spr;
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("LSR ");
        -- synthesis translate_on

      when O_SSR =>
        d.rd1:='1';
        -- synthesis translate_off
        d.strasm := opcode_txt_pad("SSR ");
        -- synthesis translate_on

      when others =>
        -- synthesis translate_off
        d.strasm      := opcode_txt_pad("UNKNOWN");
        -- synthesis translate_on
    end case;

    dec <= d;

  end process;


end behave;
