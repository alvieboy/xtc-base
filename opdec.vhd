library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.newcpupkg.all;
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


begin
  process(opcode)
  -- synthesis translate_off
    variable targetstr: string(1 to 2);
    variable sourcestr: string(1 to 5);
    variable opstr: string(1 to 7);
    variable rnum:  string(1 to 1);
  -- synthesis translate_on
  begin
    dec.opcode <= opcode;
    dec.sreg <= opcode(2 downto 0);
    dec.dreg <= opcode(5 downto 3);
    dec.memory_access<='0';
    dec.memory_write<='0';
    dec.rd1 <= '0';
    dec.rd2 <= '0';

    case opcode(11 downto 10) is
      --when "00" => dec.mask <= MASK_0;
      when "01" => dec.mask <= MASK_8;
      when "10" => dec.mask <= MASK_16;
      when "11" => dec.mask <= MASK_32;
      when others => null;
    end case;

    dec.prepost <= opcode(9);
    --dec.delta   <= opcode(unsigned(2 downto 0);

    -- synthesis translate_off
    dec.strasm <= opcode_txt_pad("UNKNOWN");
    -- synthesis translate_on

    -- Default values
    dec.blocking    <= true;
    dec.modify_a    <= false;
    dec.modify_gpr  <= false;
    dec.modify_mem  <= false;
    dec.uses        <= uses_alu2;
    dec.a_source    <= a_source_alu2;
    dec.alu2_source <= ALU2_SOURCE_A;
    dec.alu2_op     <= ALU2_IMMFIRST;
    dec.alu1_source <= ALU1_SOURCE_AR;
    dec.alu1_op     <= ALU1_UNKNOWN;
    dec.reg_source  <= reg_source_alu1;

    if opcode(15 downto 12)="1000" then
      -- IMM
      --dec.op := O_IMM;
      dec.blocking    <= false;
      dec.modify_a    <= true;
      dec.modify_gpr  <= false;
      dec.modify_mem  <= false;
      dec.uses        <= uses_alu2;
      dec.a_source    <= a_source_alu2;
      dec.alu2_source <= ALU2_SOURCE_A;
      dec.alu2_op     <= ALU2_IMMFIRST;
      -- synthesis translate_off
      dec.strasm      <= opcode_txt_pad("IMFIRST 0x" & hstr(opcode(10 downto 0)));
      -- synthesis translate_on

    elsif opcode(15 downto 12)="1001" then
      -- NEXTIMM
      --op := O_IMMN;
      dec.blocking    <= false;
      dec.modify_a    <= true;
      dec.modify_gpr  <= false;
      dec.modify_mem  <= false;
      dec.uses        <= uses_alu2;
      dec.a_source    <= a_source_alu2;
      dec.alu2_source <= ALU2_SOURCE_A;
      dec.alu2_op     <= ALU2_IMMNEXT;
      -- synthesis translate_off
      dec.strasm      <= opcode_txt_pad("IMNEXT  0x" & hstr(opcode(10 downto 0)));
      -- synthesis translate_on
    elsif opcode(15 downto 12)="0001" then

      -- ALU operations
      dec.blocking    <= false;
      if opcode(8)='1' then
        dec.modify_a    <= true;
        dec.modify_gpr  <= false;
        -- synthesis translate_off
        targetstr := "A ";
        -- synthesis translate_on
      else
        dec.modify_a    <= false;
        dec.modify_gpr  <= true;
        -- synthesis translate_off
        targetstr := regname(opcode(5 downto 3));
        -- synthesis translate_on
      end if;

      dec.modify_mem  <= false;
      dec.uses        <= uses_alu1;
      dec.a_source    <= a_source_alu1;
      dec.reg_source  <= reg_source_alu1;
      dec.rd1 <= '1';

      case opcode(11 downto 9) is
        when "000" => dec.alu1_op     <= ALU1_ADD;
        -- synthesis translate_off
        opstr :="ADD    ";
        -- synthesis translate_on
        when "001" => dec.alu1_op     <= ALU1_ADDC;
        -- synthesis translate_off
        opstr :="ADDC   ";
        -- synthesis translate_on
        when "010" => dec.alu1_op     <= ALU1_SUB;
        -- synthesis translate_off
        opstr :="SUB    ";
        -- synthesis translate_on
        when "011" => dec.alu1_op     <= ALU1_AND;
        -- synthesis translate_off
        opstr :="AND    ";
        -- synthesis translate_on
        when "100" => dec.alu1_op     <= ALU1_OR;
        -- synthesis translate_off
        opstr :="OR     ";
        -- synthesis translate_on
        when others => dec.alu1_op     <= ALU1_UNKNOWN;
      end case;

      if opcode(7)='1' then
        dec.alu1_source <= ALU1_SOURCE_AR;
        -- synthesis translate_off
        sourcestr := "A, " & regname(opcode(2 downto 0));
        -- synthesis translate_on
      else
        -- synthesis translate_off
        sourcestr := regname(opcode(2 downto 0)) & ", A";
        -- synthesis translate_on
        dec.alu1_source <= ALU1_SOURCE_RA;
      end if;
      -- synthesis translate_off
      dec.strasm <= opcode_txt_pad(opstr & sourcestr & ", " & targetstr);
      -- synthesis translate_on
--          if dst.a_or_gpr='0' then
--            dec.a_source := a_source_none_but_wrreg;
--          else
--            dec.a_source := a_source_alu;
--          end if;
      --op := O_ALU;
      
    elsif opcode(15 downto 12)="0011" then

      -- Store GPR to *GPR
      dec.rd1 <= '1';
      dec.rd2 <= '1';
      dec.blocking    <= true; -- we use both ALU
      dec.modify_a    <= false;
      dec.modify_gpr  <= true;
      dec.modify_mem  <= true;
      dec.uses        <= uses_alu1;
      dec.a_source    <= a_source_idle;
      dec.alu2_source <= ALU2_SOURCE_R;
      dec.alu2_op     <= ALU2_SADD;
      dec.alu1_source <= ALU1_SOURCE_RA;
      dec.alu1_op     <= ALU1_COPY_A;     -- We can change this ...
      --dec.dreg <= opcode(2 downto 0);
      dec.reg_source  <= reg_source_alu2;
      dec.memory_access<='1';
      dec.memory_write<='1';
      -- synthesis translate_off
      dec.strasm      <= opcode_txt_pad("ST  " & regname(opcode(2 downto 0)) & ", [" &
                      regname(opcode(5 downto 3)) & "]");
      -- synthesis translate_on
    elsif opcode(15 downto 12)="0100" then

      -- Load *GPR to A
      dec.rd1<='1';
      dec.blocking    <= false;
      dec.modify_a    <= false;
      dec.modify_gpr  <= true;
      dec.modify_mem  <= true;
      dec.uses        <= uses_alu2;
      dec.a_source    <= a_source_memory;
      dec.alu2_source <= ALU2_SOURCE_R;
      dec.alu2_op     <= ALU2_SADD;
     -- dec.alu1_source <= ALU1_SOURCE_RA;
     -- dec.alu1_op     <= ALU1_COPY_A;     -- We can change this ...
      --dec.dreg <= opcode(2 downto 0);
      dec.reg_source  <= reg_source_alu2;
      dec.memory_access<='1';
      dec.memory_write<='0';
      -- synthesis translate_off
      dec.strasm      <= opcode_txt_pad("LD  [" & regname(opcode(2 downto 0)) & "], A");
      -- synthesis translate_on
    end if;
  end process;


end behave;
