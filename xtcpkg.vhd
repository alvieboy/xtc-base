library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- synthesis translate_off
use work.txt_util.all;
-- synthesis translate_on

package xtcpkg is


  constant INSTRUCTION_CACHE: boolean := false;


  subtype opcode_type is std_logic_vector(15 downto 0);
  subtype dual_opcode_type is std_logic_vector(31 downto 0);
  subtype word_type is unsigned(31 downto 0);
  subtype word_type_std is std_logic_vector(31 downto 0);
  subtype regaddress_type is std_logic_vector(3 downto 0);

  --subtype alu1_op_type is std_logic_vector(2 downto 0);
  type alu1_op_type is (
    ALU_ADD,
    ALU_ADDC,
    ALU_SUB,
    ALU_AND,
    ALU_OR,
    ALU_COPY,
    ALU_XOR,
    ALU_UNKNOWN
  );

  --constant ALU_ADD:   alu1_op_type := "000";
  --constant ALU_ADDC:  alu1_op_type := "001";
  --constant ALU_SUB:   alu1_op_type := "010";
  --constant ALU_SUBB:  alu1_op_type := "011";
  --constant ALU_AND:   alu1_op_type := "100";
  --constant ALU_OR:    alu1_op_type := "101";
  --constant ALU_COPY:    alu1_op_type := "110";
  --constant ALU_CMPI:    alu1_op_type := "111";
--  constant ALU_UNKNOWN:  alu1_op_type := (others => 'X');

  

  --subtype alu2_op_type is std_logic_vector(2 downto 0);
  type alu2_op_type is (
    ALU_ADD,
    ALU_CMPI,
    ALU_UNKNOWN
  );

  constant SR_PC: std_logic_vector(2 downto 0) := "000";
  constant SR_Y: std_logic_vector(2 downto 0) := "001";
  constant SR_BR: std_logic_vector(2 downto 0) := "010";
  constant SR_CCSR: std_logic_vector(2 downto 0) := "011";
  constant SR_INTPC: std_logic_vector(2 downto 0) := "100";
  constant SR_INTM: std_logic_vector(2 downto 0) := "101";

  type decoded_opcode_type is (
    O_NOP,
    O_IM,
    O_LIMR,

    O_ADDI,
    O_CMPI,

    O_ADD,
    O_ADDC,
    O_SUB,
    O_AND,
    O_OR,
    O_COPY,

    O_ST,
    O_LD,

    -- Branch instructions
    O_BRIE,
    O_BRINE,
    O_BRIG,
    O_BRIGE,
    O_BRIL,
    O_BRILE,
    O_BRI,
    O_BRR,

    O_CALLR,
    O_CALLI,
    O_SSR,
    O_LSR,

    O_RET
  );

  type memory_access_type is (
    M_WORD,
    M_WORD_PREINC,
    M_WORD_PREDEC,
    M_WORD_POSTINC,
    M_WORD_POSTDEC,
    M_HWORD,
    M_HWORD_POSTINC,
    M_HWORD_PREINC,
    M_BYTE,
    M_BYTE_POSTINC,
    M_BYTE_PREINC,
    M_WORD_IND,
    M_HWORD_IND,
    M_BYTE_IND
    -- 3 left.
  );

  type loadimmtype is (
    LOADNONE,
    LOAD8,
    LOAD12
  );

  type reg_source_type is (
    reg_source_alu1,
    reg_source_alu2,
    reg_source_memory,
    reg_source_imm,
    reg_source_spr
  );

  type opuse_type is (
    uses_alu1,
    uses_alu2,
    uses_both_alu,
    uses_nothing
  );

  type opdec_type is record
    blocking:       boolean; -- OP is blocking.
    modify_gpr:     boolean; -- Modifies GPR
    modify_mem:     boolean; -- Modifies memory (write)
    uses:           opuse_type; -- General resource usage, for ALU
    alu1_op:        alu1_op_type; -- ALU1 operation
    alu2_op:        alu2_op_type; -- ALU2 operation
    opcode:         opcode_type;  -- The fetched opcode
    sreg1:          regaddress_type; -- Source GPR
    sreg2:          regaddress_type; -- Source GPR
    dreg:           regaddress_type; -- Destination GPR
    is_indirect:    boolean;        -- Indirect operation
    modify_flags:   boolean;
    macc:           memory_access_type;      -- Memory access type
    memory_access:  std_logic;      -- Bool for memory access (read or write)
    memory_write:   std_logic;      -- Bool for write
    rd1:            std_logic;      -- Read enable for GPR0
    rd2:            std_logic;      -- Read enable for GPR1
    reg_source:     reg_source_type;
    -- IMMediate helpers
    imm12:          std_logic_vector(11 downto 0);
    imm8:           std_logic_vector(7 downto 0);
    imm4:           std_logic_vector(3 downto 0);
    -- Special reg
    sr:             std_logic_vector(2 downto 0);
    loadimm:        loadimmtype;
    op:             decoded_opcode_type;
-- synthesis translate_off
    strasm:     string(1 to 25);    -- Assembly string, for debugging purposes
-- synthesis translate_on
  end record;


  type fetchunit_state_type is ( running, jumping );

  type fetch_regs_type is record
    pc, fpc, ipc:        word_type;
    state:          fetchunit_state_type;
  end record;

  type fetch_output_type is record
    r:        fetch_regs_type;
    opcode:   dual_opcode_type;
    valid:    std_logic;
  end record;


  type decode_regs_type is record
    decoded:        decoded_opcode_type;
    valid:          std_logic;
    rd1, rd2:       std_logic;
    sra1, sra2:     regaddress_type;
    dra:            regaddress_type;
    regwe:          std_logic;
    pc_lsb:         boolean;
    modify_flags:   boolean;
    op:             decoded_opcode_type;
    dreg:           regaddress_type;
    alu1_op:        alu1_op_type;
    alu2_op:        alu2_op_type;
    alu2_opcode:    opcode_type;
    reg_source:     reg_source_type;
    swap_target_reg:std_logic;
    memory_write:   std_logic;
    memory_access:  std_logic;
    la_offset:      unsigned(31 downto 0);
    macc:           memory_access_type;
    wb_is_data_address: std_logic; -- Writeback is data pointer, not alu result
    npc:            word_type;
    fpc:            word_type;
    pc:             word_type;
    -- IMMediate helpers
    imm12:          std_logic_vector(11 downto 0);
    imm8:           std_logic_vector(7 downto 0);
    imm4:           std_logic_vector(3 downto 0);

    imreg:          unsigned(31 downto 0);
    imflag:         std_logic;

    sr:             std_logic_vector(2 downto 0);
-- synthesis translate_off
    strasm:     string(1 to 50);
-- synthesis translate_on

  end record;

  type decode_output_type is record
    -- Fast-forward
    rd1, rd2:       std_logic;
    sra1, sra2:     regaddress_type;
    r: decode_regs_type;
  end record;

  type fetchdata_regs_type is record
    drq:            decode_regs_type;
  end record;

  type fetchdata_output_type is record
    r:            fetchdata_regs_type;
    rr1,rr2:      word_type_std; -- Register data
  end record;

  type execute_regs_type is record
    valid:          std_logic;
    wb_is_data_address: std_logic;
    -- Own
    br:             unsigned(31 downto 0); -- BRanch register
    alur1:          unsigned(31 downto 0);
    alur2:          unsigned(31 downto 0);
    --imreg:          unsigned(31 downto 0);
    --imflag:         std_logic;

    flag_carry:     std_logic;
    flag_borrow:    std_logic;
    flag_zero:      std_logic;
    flag_sign:      std_logic;


    data_write:     std_logic_vector(31 downto 0);
    data_address:   std_logic_vector(31 downto 0);
    data_access:    std_logic;
    data_writeenable: std_logic;
    sr:             std_logic_vector(2 downto 0);
    dreg:           regaddress_type;
    mwreg:          regaddress_type;
    regwe:          std_logic;
    macc:           memory_access_type;
    reg_source:     reg_source_type;
    jump: std_logic;
    jumpaddr: word_type;

  end record;

  type execute_output_type is record
    r: execute_regs_type;
    --jump: std_logic;
    --jumpaddr: word_type;
    -- Async stuff for writeback
    reg_source: reg_source_type;
    dreg: regaddress_type;
    sr: std_logic_vector(2 downto 0);
    
    alur1: word_type;
    alur2: word_type;
    imreg: word_type;
    regwe: std_logic;
  end record;

  type memory_regs_type is record
    -- Q-Pass from previous stage
    --wb_is_data_address: std_logic;
    --alur1:              word_type;
    --alur2:              word_type;
    --data_address:       word_type_std;
    --regwe:              std_logic;
    dreg:               regaddress_type;
    trans:                std_logic;
    -- Own registers
    --mread:              std_logic;
  end record;

  type memory_output_type is record
    r:        memory_regs_type;
    mdata:    std_logic_vector(31 downto 0);
    mreg:     regaddress_type;
    mregwe:   std_logic;
  end record;
  
  constant DontCareValue: std_logic := 'X';

  function opcode_txt_pad(strin: in string) return string;
  function regname(r: in regaddress_type) return string;

end xtcpkg;


package body xtcpkg is
  function opcode_txt_pad(strin: in string) return string is
    variable ret: string(1 to 25);
  begin
    for i in 1 to 25 loop
      ret(i):=' ';
    end loop;
    ret(1 to strin'LENGTH):=strin;
    return ret;
  end function;

  function regname(r: in regaddress_type) return string is
    variable tmp: string(1 to 3);
  begin
    case r is
      when "0000" => tmp := "R0 ";
      when "0001" => tmp := "R1 ";
      when "0010" => tmp := "R2 ";
      when "0011" => tmp := "R3 ";
      when "0100" => tmp := "R4 ";
      when "0101" => tmp := "R5 ";
      when "0110" => tmp := "R6 ";
      when "0111" => tmp := "R7 ";
      when "1000" => tmp := "R8 ";
      when "1001" => tmp := "R9 ";
      when "1010" => tmp := "R10";
      when "1011" => tmp := "R11";
      when "1100" => tmp := "R12";
      when "1101" => tmp := "R13";
      when "1110" => tmp := "R14";
      when "1111" => tmp := "R15";
      when others => tmp := "R? ";
    end case;
    return tmp;
  end function;
end;