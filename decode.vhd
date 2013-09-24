library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.newcpupkg.all;
use work.newcpucomppkg.all;

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
    jumpmsb:  in std_logic
  );
end entity decode;

architecture behave of decode is

  signal dr: decode_regs_type;
  signal dec1, dec2: opdec_type;

  -- Debug helpers

  signal dbg_can_issue_both: boolean;
  
begin

    duo.r <= dr;

    opdec1: opdec
      port map (
        opcode  => fui.opcode(31 downto 16),
        dec     => dec1
      );

    opdec2: opdec
      port map (
        opcode  => fui.opcode(15 downto 0),
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
      variable imm4:           std_logic_vector(3 downto 0);
      variable sr:             std_logic_vector(2 downto 0);
      variable alu2_opcode: opcode_type;

      variable opcdelta: std_logic_vector(2 downto 0);

      variable can_issue_both: boolean;
      variable is_pc_lsb: boolean;
      variable reg_source: reg_source_type;
      variable regwe: std_logic;
      variable prepost: std_logic;
      variable macc: memory_access_type;
      variable strasm: string(1 to 50);
      variable memory_access: std_logic;
      variable memory_write: std_logic;
      variable modify_flags: boolean;

    begin
      dw := dr;
      busy <= '0';

      rd1 := '0';
      rd2 := '0';

      can_issue_both := false;
      if not dec1.blocking and not dec2.blocking then
        -- We can issue both instructions if they do not share the same LU,
        -- nor they share the same output type.
        if dec1.uses /= dec2.uses then
            if not (dec1.modify_gpr and dec2.modify_gpr) then
              if not (dec1.modify_mem and dec2.modify_mem) then
                --can_issue_both:=true;
              end if;
          end if;
        end if;
      end if;

      is_pc_lsb:=dr.pc_lsb;

      -- Some instructions might need access to both register ports.
      -- These must be marked as "blocking".

      if not can_issue_both then
        -- TODO: choose correct instruction based on LSB of PC
        if not is_pc_lsb then
          rd1 := dec1.rd1;
          rd2 := dec1.rd2;
          ra1 := dec1.sreg1;
          ra2 := dec1.sreg2; -- Preload DREG for some insns
          imm12 := dec1.imm12;
          imm8  := dec1.imm8;
          imm4  := dec1.imm4;
          sr := dec1.sr;

          op := dec1.op;
          alu1_op := dec1.alu1_op;
          alu2_op := dec1.alu2_op;
          alu2_opcode := dec1.opcode;

          reg_source := dec1.reg_source;
          is_pc_lsb := true;
          busy <= fui.valid;
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
          is_pc_lsb := false;
        end if;
      else
        is_pc_lsb:=false;

        -- Issue two instructions at the time, one for each of the LU
        ra1 := dec1.sreg1;
        ra2 := dec2.sreg2;
        sr := (others => 'X');

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
          --reg_source := dec1.reg_source;
        else
          dreg := dec2.dreg;
          --reg_source := dec2.reg_source;
        end if;

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
        dw.dreg := dreg;
        dw.npc  := fui.r.ipc;
        dw.fpc  := fui.r.fpc;
        dw.pc  := fui.r.pc;
        if is_pc_lsb=false then
          dw.pc(1) := '1';
          dw.fpc(1) := '1';
        end if;
        if is_pc_lsb=true then
          dw.npc(1) := '1';
        end if;
        dw.op := op;
        dw.imm12 := imm12;
        dw.imm8  := imm8;
        dw.imm4  := imm4;

        dw.alu1_op := alu1_op;
        dw.alu2_op := alu2_op;
        dw.alu2_opcode := alu2_opcode;
        dw.pc_lsb      := is_pc_lsb;
        dw.reg_source := reg_source;
        dw.regwe := regwe;
        dw.wb_is_data_address := '0';
        dw.macc := macc;
        dw.sr := sr;
        dw.memory_access := memory_access;
        dw.memory_write := memory_write;
        dw.modify_flags := modify_flags;
        -- synthesis translate_off
        dw.strasm := strasm;
        -- synthesis translate_on
      else
        --dw.rd1 := '0';
        --dw.rd2 := '0';
        --dw.regwe := '0';
        busy <= freeze;
      end if;

      -- This must be modified for jump

      if jump='1' then
        if jumpmsb='1' then
          dw.pc_lsb := true;
        else
          dw.pc_lsb := false;
        end if;
      end if;

      if rst='1' or flush='1' then
        dw.valid := '0';
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
      dbg_can_issue_both <= can_issue_both;
    -- synthesis translate_on
    end process;


end behave;
