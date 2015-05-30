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
  signal dec: opdec_type;

  signal opcode_high: std_logic_vector(15 downto 0);
  signal opcode_low: std_logic_vector(15 downto 0);

--  signal pc_lsb: boolean;

begin

    opcode_high <= fui.opcode(31 downto 16) when fui.inverted='0' else fui.opcode(15 downto 0);
    opcode_low  <= fui.opcode(15 downto 0)  when fui.inverted='0' else fui.opcode(31 downto 16);

    duo.r <= dr;

    opdecoder: entity work.opdec
      port map (
        opcode_high   => opcode_high,
        opcode_low    => opcode_low,
        priv          => fui.r.priv,
        dec           => dec
      );

    process(fui, dr, clk, rst, dec, freeze, jump, jumpmsb, flush, opcode_high,opcode_low)
      variable dw: decode_regs_type;
      --variable op: decoded_opcode_type;
      variable opc1,opc2:       std_logic_vector(15 downto 0);
      variable rd1,rd2:         std_logic;
      variable ra1,ra2:         regaddress_type;
      --variable src: sourcedest_type;
      variable dreg0, dreg1:   regaddress_type;
      variable alu_op:         alu_op_type;
      variable imm16:          std_logic_vector(15 downto 0);
      variable imm8:           std_logic_vector(7 downto 0);
      variable imm_fill:       std_logic_vector(31 downto 0);
      variable sr:             std_logic_vector(2 downto 0);

      variable opcdelta: std_logic_vector(2 downto 0);

      variable can_issue_both: boolean;
      --variable is_pc_lsb: boolean;
      variable reg_source0, reg_source1: reg_source_type;
      variable regwe :std_logic;
      variable sprwe: std_logic;
      variable prepost: std_logic;
      variable macc: memory_access_type;
      variable memory_access: std_logic;
      variable memory_write: std_logic;
      variable modify_flags: boolean;
      --variable compositeloadimm: compositeloadimmtype;
      variable jump: std_logic_vector(1 downto 0);
      variable condition_clause: condition_type;
      variable alu2_imreg: std_logic;
      variable alu2_samereg: std_logic;
      --variable no_reg_conflict: boolean;
      --variable flags_source: flagssource_type;
      variable pc: word_type;
      variable imflag: std_logic;
      variable invert_alu: boolean;
      variable except_return: boolean;
      variable blocks1: std_logic;
      variable blocks2: std_logic;
      variable is_jump: boolean;

    begin
      dw := dr;
      busy <= '0';
      dual <= '0';

      rd1 := '0';
      rd2 := '0';

      --can_issue_both := false;
      modify_flags:=false;
      jump := (others => 'X');
      --jump_clause := JUMP_NONE;
      --no_reg_conflict := true;
      imflag := '0';

      -- TODO: save power, only enable RB that need..
      rd1 := dec.rd1;
      rd2 := dec.rd2;

      ra1 := dec.sreg1;
      ra2 := dec.sreg2; -- Preload DREG for some insns

      imm16 := dec.imm8h & dec.imm8l;
      imm8  := dec.imm8l;

      pc := fui.r.pc;

      sr := dec.sr;
      jump := dec.jump;
      --condition_clause := dec.condition;
      except_return:=dec.except_return;

      dw.cop_id := dec.cop_id;
      dw.cop_reg := dec.cop_reg;

      alu_op := dec.alu_op;

      reg_source0 := dec.reg_source;
      reg_source1 := dec.reg_source;
      dreg0 := dec.dreg;
      dreg1 := dec.dreg;
      blocks1 := dec.blocks;
      blocks2 := dec.blocks;


      macc := dec.macc;
      memory_access := dec.memory_access;
      memory_write := dec.memory_write;
      modify_flags := dec.modify_flags;

      if dec.modify_gpr then
          regwe:='1';
      else
          regwe:='0';
      end if;

      if dec.modify_spr then
        sprwe :='1';
      else
        sprwe :='0';
      end if;

      imflag := dec.imflag;

      if freeze='0' then
        dw.valid := fui.valid;
      end if;

      if fui.valid='1' and freeze='0' then

        dw.rd1 := rd1;
        dw.rd2 := rd2;
        dw.sra1 := ra1;
        dw.sra2 := ra2;
        dw.sprwe := sprwe;

        dw.pc   := pc;
        dw.npc := fui.npc;
        dw.fpc := fui.npc + 2;

        if dr.imflag='0' then
          dw.imreg := (others => '0');
          dw.tpc := pc;
        end if;

        case dec.loadimm is

          when LOAD8 =>
            if dr.imflag='1' then
            -- Shift.
              dw.imreg(31 downto 8) := dr.imreg(23 downto 0);
              dw.imreg(7 downto 0) := unsigned(imm8);
            else
              dw.imreg(31 downto 8) := (others => imm8(7));
              dw.imreg(7 downto 0) := unsigned(imm8);
            end if;

          when LOAD16 =>
            if dr.imflag='0' then
              dw.imreg(31 downto 15) := (others => imm16(15));
              dw.imreg(14 downto 0) := unsigned(imm16(14 downto 0));
            else
              dw.imreg(31 downto 16) := dr.imreg(15 downto 0);
              dw.imreg(15 downto 0) := unsigned(imm16(15 downto 0));
            end if;
          when LOAD24 =>
            dw.imreg(31 downto 24) := (others => dec.imm24(23));
            dw.imreg(23 downto 0) := unsigned(dec.imm24);

          when LOAD0 =>
            -- Keep imm

          when others =>
            --dw.imreg := (others => '0');
        end case;

        dw.imflag := imflag;
        dw.enable_alu := dec.enable_alu;
        dw.ismult := dec.ismult;

        dw.alu_op := alu_op;
        dw.alu_source := dec.alu_source;

        dw.wb_is_data_address := '0';
        dw.cop_en := dec.cop_en;
        dw.cop_wr := dec.cop_wr;

        dw.macc := macc;
        dw.sr := sr;
        dw.memory_access := memory_access;
        dw.memory_write := memory_write;
        dw.modify_flags := modify_flags;
        dw.blocks := blocks1 or blocks2;
        dw.dreg        := dreg0;
        dw.reg_source  := reg_source0;
        dw.regwe       := regwe;
        dw.priv         := dec.priv;
        dw.jump         := jump;
        dw.except_return:= except_return;
        dw.use_carry := dec.use_carry;
        -- Preserve condition from E24 extension (imm)
        if dr.imflag='0' then
          dw.condition_clause    := dec.condition;
        end if;

        dw.opcode := opcode_high;
        dw.opcode_low := opcode_low;
        dw.dual := dec.extended;
        dw.decoded := dec.op;
        dw.is_jump := dec.is_jump;
      else
        busy <= freeze;
      end if;


      if rst='1' or flush='1' then
        dw.valid := '0';
        --dw.delay_slot := false;
        dw.imflag := '0';
        dw.regwe := '0';
        dw.rd1   := '0';
        dw.rd2   := '0';
        dw.ismult:= '0';
        dw.blocks := '0';
        dw.cop_en := '0';
        dw.cop_wr := '0';
        dw.priv := '0';
        dw.sprwe := '0';
        dw.is_jump := false;
        dw.memory_access := '0';
        dw.memory_write := '0';
        dw.enable_alu := '0';
        dw.use_carry := '0';
        dw.modify_flags := false;
      end if;

      if dec.extended then
        dual <= '1';
      end if;

      -- fast-forward register access
      duo.rd1 <= rd1;
      duo.rd2 <= rd2;

      duo.sra1 <= ra1;
      duo.sra2 <= ra2;

      if rising_edge(clk) then
        dr <= dw;
      end if;
    -- synthesis translate_off
      --dbg_can_issue_both <= can_issue_both;
      --dbg_compositeloadimm <= compositeloadimm;
    -- synthesis translate_on
    end process;


end behave;
