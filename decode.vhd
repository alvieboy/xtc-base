library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.newcpupkg.all;

entity decode is
  port (
    clk:  in std_logic;
    rst:  in std_logic;

    -- Input for previous stages
    fui:  in fetch_output_type;

    -- Output for next stages
    duo:  out decode_output_type
  );
end entity decode;

architecture behave of decode is

    function source_from_opcode(op: in std_logic_vector(8 downto 0)) return sourcedest_type is
      variable r: sourcedest_type;
    begin
      r.gpr := op(7 downto 5);
      r.a_or_gpr := op(8);
      r.a_or_z := op(3);
      return r;
    end function;

    function dest_from_opcode(op: in std_logic_vector(8 downto 0)) return sourcedest_type is
      variable r: sourcedest_type;
    begin
      r.gpr := op(2 downto 0);
      r.a_or_gpr := op(4);
      r.a_or_z := op(2);
      return r;
    end function;

  signal dr: decode_regs_type;

  begin

    duo.r <= dr;

    process(fui, dr, clk,rst)
      variable dw: decode_regs_type;
      variable op: decoded_opcode_type;
      variable opc: std_logic_vector(15 downto 0);
      variable rd1,rd2: std_logic;
      variable ra1,ra2: std_logic_vector(2 downto 0);
      variable src: sourcedest_type;
      variable dst: sourcedest_type;
      variable alu: alu_op_type;
      variable opcdelta: std_logic_vector(2 downto 0);
    begin
      dw := dr;

      dw.frq := fui.r;

      opc := fui.opcode;
      op  := O_NOP;
      rd1 := '1';
      rd2 := '1';
  
      dw.swap_target_reg:=DontCareValue;
      dw.memory_access:='0';
      dw.memory_write:='0';
  
      -- ALU inputs
      src := source_from_opcode( opc(8 downto 0) );
      dst := dest_from_opcode( opc(8 downto 0) );



      case opc(11 downto 9) is
        when "000" => alu := ALU_ADD;
        when "001" => alu := ALU_ADDC;
        when "010" => alu := ALU_AND;
        when "011" => alu := ALU_OR;
        when "100" => alu := ALU_SUB;
        when "111" => alu := ALU_COPY_A;
        when others => alu := ALU_UNKNOWN;
      end case;

      if fui.valid='1' then
        dw.swap_target_reg:='0';
        dw.memory_write := '0';
        dw.la_offset := (others => DontCareValue);
        dw.wb_is_data_address := '0';

        case opc(10 downto 9) is
          when "00" => dw.mask := MASK_0;
          when "01" => dw.mask := MASK_8;
          when "10" => dw.mask := MASK_16;
          when "11" => dw.mask := MASK_32;
          when others => null;
        end case;
  
        if opc(15 downto 12)="1000" then
          -- IMM
          op := O_IMM;
          dw.a_source := a_source_immed;
        elsif opc(15 downto 12)="1001" then
          -- NEXTIMM
          op := O_IMMN;
          dw.a_source := a_source_immednext;
        elsif opc(15 downto 12)="0001" then
          -- ALU operations
          if dst.a_or_gpr='0' or dst.a_or_z='0' then
            dw.a_source := a_source_none_but_wrreg;
          else
            dw.a_source := a_source_alu;
          end if;
          op := O_ALU;
          
        elsif opc(15 downto 12)="1111" then
          -- MOVE
          op := O_MOVE;
          if dst.a_or_gpr='0' or dst.a_or_z='0' then
            dw.a_source := a_source_none_but_wrreg;
          else
            dw.a_source := a_source_alu;
          end if;
          alu := ALU_COPY_A; -- Sel A
        elsif opc(15 downto 12)="0010" then
          -- Jump with flags
          op := O_JMPF;
          dw.a_source := a_source_idle;
          -- JMPF    0010ffffaaaammmm
        elsif opc(15 downto 12)="0011" then
          -- Jump with flags, relative address
          op := O_JMPFR;
          dw.a_source := a_source_idle;
          -- JMPFR   0011ffffrrrrmmmm
        elsif opc(15 downto 12)="0100" then
          -- Load A with immed
          op := O_LDAI;
          dw.a_source := a_source_memory;
          dw.memory_access := '1';
          dw.swap_target_reg := '1';
          dw.prepost := '1'; -- Pre-increment.

          -- Offset for LoadA operations. Signed offset. Always word-aligned

          dw.la_offset(31 downto 10) := (others => opc(11));
          dw.la_offset(9 downto 7) := unsigned(opc(10 downto 8));
          dw.la_offset(6 downto 2) := unsigned(opc(4 downto 0));
          dw.la_offset(1 downto 0) := (others => '0');

        elsif opc(15 downto 12)="0100" then
        elsif opc(15 downto 12)="1110" then
          -- Store A
          op := O_STA;
          dw.a_source := a_source_none_but_wrreg;
          dst.a_or_gpr := '0';
          dw.memory_access := '1';
          dw.swap_target_reg := '1';
          -- Offset for StoreA operations. Signed offset. Always word-aligned
          opcdelta := opc(11) & opc(1 downto 0);
          case opcdelta is
            when "000" => dw.la_offset := x"00000000";
            when "001" => dw.la_offset := x"00000001";
            when "010" => dw.la_offset := x"00000002";
            when "011" => dw.la_offset := x"00000004";
            when "111" => dw.la_offset := x"FFFFFFFF";
            when "110" => dw.la_offset := x"FFFFFFFE";
            when "101" => dw.la_offset := x"FFFFFFFC";
            when "100" => dw.la_offset := x"FFFFFFF8"; -- ????
            when others=> dw.la_offset := (others => DontCareValue);
          end case;
          dw.prepost := opc(8);
          dw.wb_is_data_address := '1';
        else
          dw.a_source := a_source_idle;
          -- NOP
        end if;
      end if;


      dw.valid := fui.valid;
      if rst='1' then dw.valid := '0'; end if;

      if fui.valid='1' then
        dw.frq := fui.r;
        dw.opcode := fui.opcode;
        dw.decoded := op;
        dw.rd1 := rd1;
        dw.rd2 := rd2;
        dw.ra1 := src.gpr;
        dw.ra2 := dst.gpr;
        dw.source := src;
        dw.dest   := dst;
        dw.alu_op := alu;
      end if;
  
      if rising_edge(clk) then
        dr <= dw;
      end if;
    end process;
end behave;
