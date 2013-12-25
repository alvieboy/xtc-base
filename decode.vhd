library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.xtcpkg.all;
use work.xtccomppkg.all;

entity decode is
  port (
    clk:  in std_logic;
    rst:  in std_logic;

    -- Input for previous stages
    fui:  in fetch_output_type;

    -- Output for next stages
    duo:  out decode_output_type;
    busy: out std_logic;
    freeze: in std_logic;
    flush: in std_logic;
    jump:  in std_logic;
    dual:   out std_logic;
    jumpmsb:  in std_logic
  );
end entity decode;

architecture behave of decode is

  signal dr: decode_regs_type;
  signal dec1, dec2: opdec_type;

  -- Debug helpers

  signal dbg_can_issue_both: boolean;

  type compositeloadimmtype is (
    LOAD0,
    LOAD8,
    LOAD12,
    LOAD12_12,
    LOAD12_8,
    LOAD_OTHER8,
    LOAD_OTHER12,
    LOADNONE
  );
  signal dbg_compositeloadimm: compositeloadimmtype;

  signal opcode1: std_logic_vector(15 downto 0);
  signal opcode2: std_logic_vector(15 downto 0);

--  signal pc_lsb: boolean;

begin

    opcode1 <= fui.opcode(31 downto 16) when fui.inverted='0' else fui.opcode(15 downto 0);
    opcode2 <= fui.opcode(15 downto 0) when fui.inverted='0' else fui.opcode(31 downto 16);

    duo.r <= dr;

    opdec1: opdec
      port map (
        opcode  => opcode1,
        dec     => dec1
      );

    opdec2: opdec
      port map (
        opcode  => opcode2,
        dec     => dec2
      );

    process(fui, dr, clk, rst, dec1, dec2, freeze, jump, jumpmsb, flush)
      variable dw: decode_regs_type;
      --variable op: decoded_opcode_type;
      variable opc1,opc2: std_logic_vector(15 downto 0);
      variable rd1,rd2,rd3,rd4: std_logic;
      variable ra1,ra2,ra3,ra4: regaddress_type;
      --variable src: sourcedest_type;
      variable dreg0, dreg1: regaddress_type;
      variable alu1_op: alu1_op_type;
      variable alu2_op: alu2_op_type;
      variable imm12:          std_logic_vector(11 downto 0);
      variable imm8:           std_logic_vector(7 downto 0);
      variable imm24:          std_logic_vector(23 downto 0);
      variable imm20:          std_logic_vector(19 downto 0);

      variable imm4:           std_logic_vector(3 downto 0);
      variable imm_fill:       std_logic_vector(31 downto 0);
      variable sr:             std_logic_vector(2 downto 0);
      variable alu2_opcode: opcode_type;

      variable opcdelta: std_logic_vector(2 downto 0);

      variable can_issue_both: boolean;
      --variable is_pc_lsb: boolean;
      variable reg_source0, reg_source1: reg_source_type;
      variable regwe0, regwe1: std_logic;
      variable prepost: std_logic;
      variable macc: memory_access_type;
      variable strasm: string(1 to 50);
      variable memory_access: std_logic;
      variable memory_write: std_logic;
      variable modify_flags: boolean;
      variable compositeloadimm: compositeloadimmtype;
      variable jump: std_logic_vector(1 downto 0);
      variable jump_clause: jumpcond_type;
      variable br_source: br_source_type;
      variable alu2_imreg: std_logic;
      variable no_reg_conflict: boolean;
      variable flags_source: flagssource_type;
      variable pc: word_type;

    begin
      dw := dr;
      busy <= '0';
      dual <= '0';

      rd1 := '0';
      rd2 := '0';
      rd3 := '0';
      rd4 := '0';

      imm20 := (others => 'X');
      imm24 := (others => 'X');
      can_issue_both := false;
      modify_flags:=false;
      jump := (others => 'X');
      jump_clause := JUMP_NONE;
      br_source := br_source_none;
      no_reg_conflict := true;

      if dec1.modify_gpr then
        -- Check if we're writing something used by the second insn
        if dec2.rd1='1' and dec1.dreg = dec2.sreg1 then
          no_reg_conflict := false;
        end if;
        if dec2.rd2='1' and dec1.dreg = dec2.sreg2 then
          no_reg_conflict := false;
        end if;
      end if;

      if not dec1.blocking then
        -- We can issue both instructions if they do not share the same LU,
        -- nor they share the same output type.

        -- Also, some mix of IMM is not allowed.

        if dec1.uses /= dec2.uses or (dec1.uses=uses_nothing or dec2.uses=uses_nothing) then
           if no_reg_conflict then
           -- if not (dec1.modify_gpr and dec2.modify_gpr) then
              if not (dec1.modify_mem and dec2.modify_mem) then
                can_issue_both:=true;
              end if;
          end if;
        end if;
      end if;

      -- Some conjuntion of IMM is also not allowed, if the IMM is to be reset.

      if dec1.loadimm=LOAD8 and dec2.loadimm/=LOADNONE then
        can_issue_both := false;
      end if;

      if dec1.loadimm=LOAD0 and dec2.loadimm/=LOADNONE then
        can_issue_both := false;
      end if;

      if fui.r.unaligned_jump='1' then
        can_issue_both := false;
      end if;

      --is_pc_lsb:=dr.pc_lsb;


      if not can_issue_both then

        -- TODO: save power, only enable RB that need..
        rd1 := dec1.rd1;
        rd2 := dec1.rd2;
        rd3 := dec1.rd1;
        rd4 := dec1.rd2;

        ra1 := dec1.sreg1;
        ra2 := dec1.sreg2; -- Preload DREG for some insns
        ra3 := dec1.sreg1;
        ra4 := dec1.sreg2;

        imm12 := dec1.imm12;
        imm8  := dec1.imm8;
        imm4  := dec1.imm4;
        pc := fui.r.pc;

        sr := dec1.sr;
        jump := dec1.jump;
        jump_clause := dec1.jump_clause;
        br_source := dec1.br_source;

        case dec1.loadimm is
          when LOAD8 =>  compositeloadimm := LOAD8;
          when LOAD12 =>  compositeloadimm := LOAD12;
          when LOAD0 =>  compositeloadimm := LOAD0;
          when others =>  compositeloadimm := LOADNONE;
        end case;

      --  op := dec1.op;
        alu1_op := dec1.alu1_op;
        alu2_op := dec1.alu2_op;
        alu2_opcode := dec1.opcode;
        alu2_imreg := dec1.alu2_imreg;

        reg_source0 := dec1.reg_source;
        reg_source1 := dec1.reg_source;
        dreg0 := dec1.dreg;
        dreg1 := dec1.dreg;

        macc := dec1.macc;
        memory_access := dec1.memory_access;
        memory_write := dec1.memory_write;
        modify_flags := dec1.modify_flags;
        -- synthesis translate_off
        strasm := dec1.strasm & opcode_txt_pad("");
        -- synthesis translate_on

        if dec1.uses=uses_alu1 then
          flags_source := FLAGS_ALU1;
        else
          flags_source := FLAGS_ALU2;
        end if;

        if dec1.modify_gpr then
          if dec1.uses = uses_alu1 then
            regwe0:='1';
            regwe1:='0';
          else
            regwe0:='0';
            regwe1:='1';
          end if;
        else
          regwe0:='0';
          regwe1:='0';
        end if;
      else

        -- Issue two instructions at the time, one for each of the LU

        pc := fui.r.pc + 2;

        sr := (others => 'X');
        dual <= '1';

        prepost := DontCareValue; -- No prepost in composite
        memory_access := '0';
        memory_write := DontCareValue;

        -- RD1/RD2 are output to ALU1.

        if dec1.uses/=uses_alu2 then
          ra1 := dec1.sreg1;
          ra2 := dec1.sreg2;
          ra3 := dec2.sreg1;
          ra4 := dec2.sreg2;

          rd1 := dec1.rd1;
          rd2 := dec1.rd2;
          dreg0 := dec1.dreg;
          dreg1 := dec2.dreg;
          reg_source0 := dec1.reg_source;
          reg_source1 := dec2.reg_source;
          if dec1.modify_gpr then
            regwe0 := '1';
          else
            regwe0 := '0';
          end if;
          if dec2.modify_gpr then
            regwe1 := '1';
          else
            regwe1 := '0';
          end if;

          rd3 := dec2.rd1;
          rd4 := dec2.rd2;

          alu1_op := dec1.alu1_op;
          alu2_op := dec2.alu2_op;
          alu2_opcode := dec2.opcode;
          alu2_imreg  := dec2.alu2_imreg;

        else

          ra1 := dec2.sreg1;
          ra2 := dec2.sreg2;
          ra3 := dec1.sreg1;
          ra4 := dec1.sreg2;

          rd1 := dec2.rd1;
          rd2 := dec2.rd2;

          rd3 := dec1.rd1;
          rd4 := dec1.rd2;

          dreg0 := dec2.dreg;
          dreg1 := dec1.dreg;
          reg_source0 := dec2.reg_source;
          reg_source1 := dec1.reg_source;
          if dec2.modify_gpr then
            regwe0 := '1';
          else
            regwe0 := '0';
          end if;
          if dec1.modify_gpr then
            regwe1 := '1';
          else
            regwe1 := '0';
          end if;

          alu1_op := dec2.alu1_op;
          alu2_op := dec1.alu2_op;
          alu2_opcode := dec1.opcode;
          alu2_imreg  := dec1.alu2_imreg;

        end if;

        if dec1.uses=uses_alu1 then
          flags_source := FLAGS_ALU1;
        else
          flags_source := FLAGS_ALU2;
        end if;

        if dec2.br_source=BR_SOURCE_NONE then
          br_source := dec1.br_source;
        else
          br_source := dec2.br_source;
        end if;
        -- Jump
        if dec1.jump_clause=JUMP_NONE then
          jump_clause := dec2.jump_clause;
          jump := dec2.jump;
        else
          jump_clause := dec1.jump_clause;
          jump := dec1.jump;
        end if;
        -- synthesis translate_off
        strasm := dec1.strasm & dec2.strasm;
        -- synthesis translate_on


        imm20 := dec1.imm12 & dec2.imm8;
        imm24 := dec1.imm12 & dec2.imm12;

        imm12 := (others => 'X');--dec2.imm12;
        imm8  := (others => 'X');--dec2.imm8;

        if dec1.memory_access='1' then
          macc := dec1.macc;
          memory_access := dec1.memory_access;
          memory_write := dec1.memory_write;
        else
          macc := dec2.macc;
          memory_access := dec2.memory_access;
          memory_write := dec2.memory_write;

        end if;


        case dec1.loadimm is
          when LOAD12 =>
            case dec2.loadimm is
              when LOAD8 => compositeloadimm := LOAD12_8;
                imm8  := dec1.imm8;
              when LOAD12 => compositeloadimm := LOAD12_12;
                imm12 := dec1.imm12;
              when others => compositeloadimm := LOAD12;
                imm12 := dec1.imm12;
            end case;

          when LOAD8 =>
            imm8  := dec1.imm8;
            imm12 := dec1.imm12;
            compositeloadimm := LOAD8; -- dec2 is not IMM, we ensured that.

          when others =>
            case dec2.loadimm is
              when LOAD8 => compositeloadimm := LOAD8;
                imm8  := dec2.imm8;
              when LOAD12 => compositeloadimm := LOAD12;
                imm12 := dec2.imm12;
              when others => compositeloadimm := LOADNONE;
            end case;

        end case;
      end if;

      opc1 := dec1.opcode;
      opc2 := dec2.opcode;

      dw.swap_target_reg:=DontCareValue;
      --dw.memory_access:='0';
      --dw.memory_write:='0';
  
      if freeze='0' then
        dw.valid := fui.valid;
      end if;

      if fui.valid='1' and freeze='0' then
        --dw.decoded := op;
        dw.rd1 := rd1;
        dw.rd2 := rd2;
        dw.rd3 := rd3;
        dw.rd4 := rd4;
        dw.sra1 := ra1;
        dw.sra2 := ra2;
        dw.sra3 := ra3;
        dw.sra4 := ra4;

        dw.fpc  := pc + 4;
        dw.pc   := pc;
        dw.npc  := pc + 2;

        --dw.op := op;
        dw.imm12 := imm12;
        dw.imm8  := imm8;

        if dr.imflag='0' then
          dw.imreg := (others => '0');
        end if;


        case compositeloadimm is

          when LOAD8 =>
            if dr.imflag='1' then
            -- Shift.
              dw.imreg(31 downto 8) := dr.imreg(23 downto 0);
              dw.imreg(7 downto 0) := unsigned(imm8);
            else
              dw.imreg(31 downto 8) := (others => imm8(7));
              dw.imreg(7 downto 0) := unsigned(imm8);
            end if;

          when LOAD12 =>
            if dr.imflag='0' then
              dw.imreg(31 downto 12) := (others => imm12(11));
              dw.imreg(11 downto 0) := unsigned(imm12(11 downto 0));
            else
              dw.imreg(31 downto 12) := dr.imreg(31-12 downto 0);
              dw.imreg(11 downto 0) := unsigned(imm12(11 downto 0));
            end if;

          when LOAD12_12 =>
            if dr.imflag='0' then
              dw.imreg(31 downto 24) := (others => imm24(23));
              dw.imreg(23 downto 0) := unsigned(imm24(23 downto 0));
            else
              dw.imreg(31 downto 24) := dr.imreg(31-24 downto 0);
              dw.imreg(23 downto 0) := unsigned(imm24(23 downto 0));
            end if;

          when LOAD12_8 =>

            if dr.imflag='0' then
              dw.imreg(31 downto 20) := (others => imm20(19));
              dw.imreg(19 downto 0) := unsigned(imm20(19 downto 0));
            else
              dw.imreg(31 downto 20) := dr.imreg(31-20 downto 0);
              dw.imreg(19 downto 0) := unsigned(imm20(19 downto 0));
            end if;
            
          when LOAD0 =>
            -- Keep imm

          when others =>
            dw.imreg := (others => '0');
        end case;

          if (compositeloadimm = LOAD12 and can_issue_both=false) or compositeloadimm = LOAD12_12 then
            dw.imflag := '1';
          else
            dw.imflag := '0';
          end if;

        dw.alu1_op := alu1_op;
        dw.alu2_op := alu2_op;
        dw.alu2_opcode := alu2_opcode;
        dw.alu2_imreg := alu2_imreg;
        --dw.pc_lsb      := is_pc_lsb;
        dw.wb_is_data_address := '0';
        dw.macc := macc;
        dw.sr := sr;
        dw.memory_access := memory_access;
        dw.memory_write := memory_write;
        dw.modify_flags := modify_flags;
        dw.flags_source := flags_source;

        dw.dreg0       := dreg0;
        dw.dreg1       := dreg1;
        dw.reg_source0 := reg_source0;
        dw.reg_source1 := reg_source1;
        dw.regwe0      := regwe0;
        dw.regwe1      := regwe1;

        dw.jump         := jump;
        dw.jump_clause  := jump_clause;
        dw.br_source    := br_source;
        -- synthesis translate_off
        dw.strasm := strasm;
        -- synthesis translate_on
      else
        --dw.rd1 := '0';
        --dw.rd2 := '0';
        --dw.regwe := '0';
        busy <= freeze;
      end if;

      if rst='1' or flush='1' then
        dw.valid := '0';
        dw.imflag := '0';
      end if;

      -- fast-forward register access
      duo.rd1 <= rd1;
      duo.rd2 <= rd2;
      duo.rd3 <= rd3;
      duo.rd4 <= rd4;

      duo.sra1 <= ra1;
      duo.sra2 <= ra2;
      duo.sra3 <= ra3;
      duo.sra4 <= ra4;

      --pc_lsb <= is_pc_lsb;

      if rising_edge(clk) then
        dr <= dw;
      end if;
    -- synthesis translate_off
      dbg_can_issue_both <= can_issue_both;
      dbg_compositeloadimm <= compositeloadimm;
    -- synthesis translate_on
    end process;


end behave;
