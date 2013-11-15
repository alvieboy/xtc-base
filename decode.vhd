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

    opcode1 <= fui.opcode(31 downto 16);
    opcode2 <= fui.opcode(15 downto 0);

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
      variable op: decoded_opcode_type;
      variable opc1,opc2: std_logic_vector(15 downto 0);
      variable rd1,rd2: std_logic;
      variable ra1,ra2: regaddress_type;
      --variable src: sourcedest_type;
      variable dreg: regaddress_type;
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
      variable reg_source: reg_source_type;
      variable regwe: std_logic;
      variable prepost: std_logic;
      variable macc: memory_access_type;
      variable strasm: string(1 to 50);
      variable memory_access: std_logic;
      variable memory_write: std_logic;
      variable modify_flags: boolean;
      variable compositeloadimm: compositeloadimmtype;
    begin
      dw := dr;
      busy <= '0';
      dual <= '0';

      rd1 := '0';
      rd2 := '0';

      can_issue_both := false;
      if not dec1.blocking and not dec2.blocking then
        -- We can issue both instructions if they do not share the same LU,
        -- nor they share the same output type.

        -- Also, some mix of IMM is not allowed.

        if dec1.uses /= dec2.uses or (dec1.uses=uses_nothing or dec2.uses=uses_nothing) then
            if not (dec1.modify_gpr and dec2.modify_gpr) then
              if not (dec1.modify_mem and dec2.modify_mem) then
                can_issue_both:=true;
              end if;
          end if;
        end if;
      end if;

      -- Some conjuntion of IMM is also not allowed, if the IMM is to be reset.

      if dec1.loadimm=LOAD8 then
        can_issue_both := false;
      end if;

      --is_pc_lsb:=dr.pc_lsb;

      -- Some instructions might need access to both register ports.
      -- These must be marked as "blocking".

      if not can_issue_both then
        -- TODO: choose correct instruction based on LSB of PC
        if true then
          rd1 := dec1.rd1;
          rd2 := dec1.rd2;
          ra1 := dec1.sreg1;
          ra2 := dec1.sreg2; -- Preload DREG for some insns
          imm12 := dec1.imm12;
          imm8  := dec1.imm8;
          imm4  := dec1.imm4;
          sr := dec1.sr;

          case dec1.loadimm is
            when LOAD8 =>  compositeloadimm := LOAD8;
            when LOAD12 =>  compositeloadimm := LOAD12;
            when others =>  compositeloadimm := LOADNONE;
          end case;

          op := dec1.op;
          alu1_op := dec1.alu1_op;
          alu2_op := dec1.alu2_op;
          alu2_opcode := dec1.opcode;

          reg_source := dec1.reg_source;
          --is_pc_lsb := true;
          --busy <= fui.valid;
          dreg := dec1.dreg;
          macc := dec1.macc;
          memory_access := dec1.memory_access;
          memory_write := dec1.memory_write;
          modify_flags := dec1.modify_flags;

          -- synthesis translate_off
          strasm := dec1.strasm & opcode_txt_pad("; (msb)");
          -- synthesis translate_on

          if dec1.modify_gpr then regwe:='1'; else regwe:='0'; end if;
        else
          ra1 := dec2.sreg1;
          ra2 := dec2.sreg2;
          rd1 := dec2.rd1;
          rd2 := dec2.rd2;
          imm12 := dec2.imm12;
          imm8  := dec2.imm8;
          imm4  := dec2.imm4;
          sr := dec2.sr;

          case dec2.loadimm is
            when LOAD8 =>  compositeloadimm := LOAD8;
            when LOAD12 =>  compositeloadimm := LOAD12;
            when others =>  compositeloadimm := LOADNONE;
          end case;

          op := dec2.op;
          alu1_op := dec2.alu1_op;
          alu2_op := dec2.alu2_op;
          alu2_opcode := dec2.opcode;
          reg_source := dec2.reg_source;
          dreg := dec2.dreg;
          if dec2.modify_gpr then regwe:='1'; else regwe:='0'; end if;
          macc := dec2.macc;
          memory_access := dec2.memory_access;
          memory_write := dec2.memory_write;
          modify_flags := dec2.modify_flags;

          -- synthesis translate_off
          strasm := dec2.strasm & opcode_txt_pad("; (lsb)");
          -- synthesis translate_on
        end if;
      else

        -- Issue two instructions at the time, one for each of the LU
        ra1 := dec1.sreg1;
        ra2 := dec2.sreg2;
        sr := (others => 'X');
        dual <= '1';

        prepost := DontCareValue; -- No prepost in composite
        memory_access := '0';
        memory_write := DontCareValue;

        if dec1.uses=uses_alu1 then
          rd1 := dec1.rd1;
          rd2 := dec2.rd2;
          alu1_op := dec1.alu1_op;
          alu2_op := dec2.alu2_op;
          alu2_opcode := dec2.opcode;
        else
          rd1 := dec2.rd1;
          rd2 := dec1.rd2;
          alu1_op := dec2.alu1_op;
          alu2_op := dec1.alu2_op;
          alu2_opcode := dec1.opcode;
        end if;
        -- synthesis translate_off
        strasm := dec1.strasm & dec2.strasm;
        -- synthesis translate_on
        if dec1.modify_gpr then
          dreg := dec1.dreg;
          reg_source := dec1.reg_source;
        else
          dreg := dec2.dreg;
          reg_source := dec2.reg_source;
        end if;

        imm20 := dec1.imm12 & dec2.imm8;
        imm24 := dec1.imm12 & dec2.imm12;

        imm12 := (others => 'X');--dec2.imm12;
        imm8  := (others => 'X');--dec2.imm8;

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

          when LOAD8 => compositeloadimm := LOAD8; -- dec2 is not IMM, we ensured that.

          when others =>
            case dec2.loadimm is
              when LOAD8 => compositeloadimm := LOAD8;
                imm8  := dec2.imm8;
              when LOAD12 => compositeloadimm := LOAD12;
                imm12 := dec2.imm12;
              when others => compositeloadimm := LOADNONE;
            end case;

        end case;


        regwe:='0';
        if dec1.modify_gpr or dec2.modify_gpr then
          regwe:='1';
        end if;

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
        dw.decoded := op;
        dw.rd1 := rd1;
        dw.rd2 := rd2;
        dw.sra1 := ra1;
        dw.sra2 := ra2;

        dw.fpc  := fui.r.pc + 4;
        dw.pc   := fui.r.pc;
        dw.npc  := fui.r.pc + 2;

        dw.op := op;
        dw.imm12 := imm12;
        dw.imm8  := imm8;
        dw.imm4  := imm4;

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

            -- Not yet
          when LOAD12_8 =>

            if dr.imflag='0' then
              dw.imreg(31 downto 20) := (others => imm20(19));
              dw.imreg(19 downto 0) := unsigned(imm20(19 downto 0));
            else
              dw.imreg(31 downto 20) := dr.imreg(31-20 downto 0);
              dw.imreg(19 downto 0) := unsigned(imm20(19 downto 0));
            end if;
            -- Not yet
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
        --dw.pc_lsb      := is_pc_lsb;
        dw.wb_is_data_address := '0';
        dw.macc := macc;
        dw.sr := sr;
        dw.memory_access := memory_access;
        dw.memory_write := memory_write;
        dw.modify_flags := modify_flags;

        dw.dreg0       := dreg;
        dw.reg_source0 := reg_source;
        dw.regwe0      := regwe;

        dw.dreg1       := dreg;
        dw.reg_source1 := reg_source;
        dw.regwe1      := '0';--regwe;

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
      duo.sra1 <= ra1;
      duo.sra2 <= ra2;

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
