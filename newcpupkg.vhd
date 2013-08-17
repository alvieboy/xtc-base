library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- synthesis translate_off
use work.txt_util.all;
-- synthesis translate_on

package newcpupkg is

  subtype opcode_type is std_logic_vector(15 downto 0);
  subtype dual_opcode_type is std_logic_vector(31 downto 0);
  subtype word_type is unsigned(31 downto 0);
  subtype word_type_std is std_logic_vector(31 downto 0);
  subtype regaddress_type is std_logic_vector(2 downto 0);

  type alu1_op_type is (
    ALU1_ADD,
    ALU1_ADDC,
    ALU1_SUB,
    ALU1_AND,
    ALU1_OR,
    ALU1_COPY_A,
    ALU1_UNKNOWN
  );

  type alu2_op_type is (
    ALU2_NOT,
    ALU2_IMMFIRST,
    ALU2_IMMNEXT,
    ALU2_COPY,
    ALU2_SADD,
    ALU2_UNKNOWN
  );

  type alu2_source_type is (
    ALU2_SOURCE_A,
    ALU2_SOURCE_R
  );

  type alu1_source_type is (
    ALU1_SOURCE_AR,
    ALU1_SOURCE_RA
  );
  
  type decoded_opcode_type is (
    O_NOP,
    O_IMM,
    O_IMMN,
    O_ALU,
    O_LDAI,
    O_LDA,
    O_STA,
    O_MOVE,
    O_JMPF,
    O_JMPFR
  );

  type mask_type is (
    MASK_8,
    MASK_16,
    MASK_32
  );

  type a_source_type is (
    a_source_alu1,
    a_source_alu2,
    a_source_br,
    a_source_memory,
    a_source_idle
  );

  type reg_source_type is (
    reg_source_alu1,
    reg_source_alu2,
    reg_source_memory
  );

  type opuse_type is (
    uses_alu1,
    uses_alu2,
    uses_both_alu,
    uses_nothing
  );

  type opdec_type is record
    blocking:       boolean; -- OP is blocking.
    modify_a:       boolean; -- Modifies Accumulator
    modify_gpr:     boolean; -- Modifies GPR
    modify_mem:     boolean; -- Modifies memory (write)
    uses:           opuse_type; -- General resource usage, for ALU
    alu1_op:        alu1_op_type; -- ALU1 operation
    alu2_op:        alu2_op_type; -- ALU2 operation
    opcode:         opcode_type;  -- The fetched opcode
    a_source:       a_source_type; -- Source for A register
    alu1_source:    alu1_source_type; -- ALU1 source
    alu2_source:    alu2_source_type; -- ALU2 source
    sreg:           regaddress_type; -- Source GPR
    dreg:           regaddress_type; -- Destination GPR
    reg_source:     reg_source_type; -- GPR source
    mask:           mask_type;      -- Masking for memory accesses
    prepost:        std_logic;      -- Pre or post increment pointer
    memory_access:  std_logic;      -- Bool for memory access (read or write)
    memory_write:   std_logic;      -- REMOVE
    rd1:            std_logic;      -- Read enable for GPR0
    rd2:            std_logic;      -- Read enable for GPR1
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
    alu1_source:    alu1_source_type;
    alu2_source:    alu2_source_type;
    pc_lsb:         boolean;
    dreg:           regaddress_type;
    alu1_op:        alu1_op_type;
    alu2_op:        alu2_op_type;
    alu2_opcode:    opcode_type;
    a_source:       a_source_type;
    reg_source:     reg_source_type;
    swap_target_reg:std_logic;
    memory_write:   std_logic;
    memory_access:  std_logic;
    la_offset:      unsigned(31 downto 0);
    mask:           mask_type;
    prepost:        std_logic;
    wb_is_data_address: std_logic; -- Writeback is data pointer, not alu result
    npc:            word_type;
-- synthesis translate_off
    strasm:     string(1 to 50);
-- synthesis translate_on

  end record;

  type decode_output_type is record
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
    a:              unsigned(31 downto 0);
    br:             unsigned(31 downto 0); -- BRanch register
    alur1:          unsigned(31 downto 0);
    alur2:          unsigned(31 downto 0);

    flag_carry:     std_logic;
    flag_borrow:    std_logic;
    flag_zero:      std_logic;
    flag_sign:      std_logic;
    --rb2_we:         std_logic;
    --reg2_addr:      std_logic_vector(2 downto 0);
    --rb2_wr:         std_logic_vector(31 downto 0);
    data_write:     std_logic_vector(31 downto 0);
    data_address:   std_logic_vector(31 downto 0);
    data_access:    std_logic;
    data_writeenable: std_logic;
    dreg:           regaddress_type;
    regwe:          std_logic;
    mask:           mask_type;
    reg_source:     reg_source_type;
  end record;

  type execute_output_type is record
    r: execute_regs_type;
    jump: std_logic;
    jumpaddr: word_type;
  end record;

  type memory_regs_type is record
    -- Q-Pass from previous stage
    wb_is_data_address: std_logic;
    alur1:              word_type;
    alur2:              word_type;
    data_address:       word_type_std;
    regwe:              std_logic;
    dreg:               regaddress_type;
    -- Own registers
    mread:              std_logic;
  end record;

  type memory_output_type is record
    r: memory_regs_type;
    mdata: std_logic_vector(31 downto 0);
  end record;
  
  constant DontCareValue: std_logic := 'X';

  function opcode_txt_pad(strin: in string) return string;
  function regname(r: in std_logic_vector(2 downto 0)) return string;

end newcpupkg;


package body newcpupkg is
  function opcode_txt_pad(strin: in string) return string is
    variable ret: string(1 to 25);
  begin
    for i in 1 to 25 loop
      ret(i):=' ';
    end loop;
    ret(1 to strin'LENGTH):=strin;
    return ret;
  end function;

  function regname(r: in std_logic_vector(2 downto 0)) return string is
    variable tmp: string(1 to 2);
  begin
    case r is
      when "000" => tmp := "R0";
      when "001" => tmp := "R1";
      when "010" => tmp := "R2";
      when "011" => tmp := "R3";
      when "100" => tmp := "R4";
      when "101" => tmp := "R5";
      when "110" => tmp := "R6";
      when "111" => tmp := "R7";
      when others => tmp := "R?";
    end case;
    return tmp;
  end function;
end;
