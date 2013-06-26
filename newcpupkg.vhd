library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package newcpupkg is

  subtype opcode_type is std_logic_vector(15 downto 0);
  subtype word_type is unsigned(31 downto 0);
  subtype word_type_std is std_logic_vector(31 downto 0);
  subtype regaddress_type is std_logic_vector(2 downto 0);

  type sourcedest_type is record
    gpr:      regaddress_type;
    a_or_gpr: std_logic;
    a_or_z:   std_logic;
  end record;

  type alu_op_type is (
    ALU_ADD,
    ALU_ADDC,
    ALU_SUB,
    ALU_AND,
    ALU_OR,
    ALU_COPY_A,
    ALU_UNKNOWN
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
    MASK_0, --??
    MASK_8,
    MASK_16,
    MASK_32
  );

  type a_source_type is (
    a_source_alu,
    a_source_immed,
    a_source_immednext,
    a_source_none_but_wrreg,
    a_source_memory,
    a_source_idle
  );
  type fetch_regs_type is record
    pc, npc, fpc:   word_type;
  end record;

  type fetch_output_type is record
    r:        fetch_regs_type;
    opcode:   opcode_type;
    valid:    std_logic;
  end record;


  type decode_regs_type is record
    frq:            fetch_regs_type;
    opcode:         opcode_type;
    decoded:        decoded_opcode_type;
    valid:          std_logic;
    rd1, rd2:       std_logic;
    ra1, ra2:       regaddress_type;
    source:         sourcedest_type;
    dest:           sourcedest_type;
    alu_op:         alu_op_type;
    a_source:       a_source_type;
    swap_target_reg:std_logic;
    memory_write:   std_logic;
    memory_access:  std_logic;
    la_offset:      unsigned(31 downto 0);
    mask:           mask_type;
    prepost:        std_logic;
    wb_is_data_address: std_logic; -- Writeback is data pointer, not alu result
  end record;

  type decode_output_type is record
    r: decode_regs_type;
  end record;

  type fetchdata_regs_type is record
    drq:            decode_regs_type;
  end record;

  type fetchdata_output_type is record
    r:            fetchdata_regs_type;
    rr:           word_type_std; -- Register data
  end record;

  type execute_regs_type is record
    --fdrq:           fetchdata_regs_type;

    valid:          std_logic;
    wb_is_data_address: std_logic;
    -- Own
    a:              unsigned(31 downto 0);
    alur:           unsigned(31 downto 0);
    flag_carry:     std_logic;
    flag_borrow:    std_logic;
    flag_zero:      std_logic;
    flag_sign:      std_logic;
    rb2_we:         std_logic;
    reg2_addr:      std_logic_vector(2 downto 0);
    rb2_wr:         std_logic_vector(31 downto 0);
    data_write:     std_logic_vector(31 downto 0);
    data_address:   std_logic_vector(31 downto 0);
    data_access:    std_logic;
    data_writeenable: std_logic;
  end record;

  type execute_output_type is record
    r: execute_regs_type;
  end record;

  type memory_regs_type is record
    -- Q-Pass from previous stage
    wb_is_data_address: std_logic;
    alur:               word_type;
    data_address:       word_type_std;
    rb2_we:             std_logic;
    reg2_addr:          regaddress_type;
    -- Own registers
    mread:              std_logic;
  end record;

  type memory_output_type is record
    r: memory_regs_type;
    mdata: std_logic_vector(31 downto 0);
  end record;
  
  constant DontCareValue: std_logic := 'X';


end newcpupkg;


