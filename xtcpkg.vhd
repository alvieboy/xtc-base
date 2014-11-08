library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.wishbonepkg.all;

-- synthesis translate_off
use work.txt_util.all;
-- synthesis translate_on

package xtcpkg is


  constant INSTRUCTION_CACHE: boolean := true;
  constant DATA_CACHE: boolean := true;
  constant MMU_ENABLED: boolean := false;
  constant MULT_ENABLED: boolean := true;

  constant EXTRA_PIPELINE: boolean := false;
  constant FETCHDATA_STAGE: boolean := true;

  constant DEBUG_OPCODES: boolean := false;
  constant DEBUG_MEMORY: boolean := false;
  constant ENABLE_SHIFTER: boolean := true;

  constant TRACECLOCK: boolean := false;
  constant RESETADDRESS: unsigned(31 downto 0) := x"80000000";

  subtype opcode_type is std_logic_vector(15 downto 0);
  subtype dual_opcode_type is std_logic_vector(31 downto 0);
  subtype word_type is unsigned(31 downto 0);
  subtype word_type_std is std_logic_vector(31 downto 0);
  subtype regaddress_type is std_logic_vector(3 downto 0);

  type alu_source_type is (
    alu_source_reg,
    alu_source_immed
  );

  type alu_op_type is (
    ALU_ADD,
    ALU_ADDC,
    ALU_SUB,
    ALU_SUBB,
    ALU_AND,
    ALU_OR,
    ALU_XOR,
    ALU_ADDRI,
    ALU_CMP,
    ALU_SRA,
    ALU_SRL,
    ALU_SHL,
    ALU_NOT,
    ALU_MUL,
    ALU_SEXTB,
    ALU_SEXTS
  );

  constant SR_Y: std_logic_vector(2 downto 0) := "001";
  constant SR_CCSR: std_logic_vector(2 downto 0) := "011";
  constant SR_INTPC: std_logic_vector(2 downto 0) := "100";
  constant SR_INTM: std_logic_vector(2 downto 0) := "101";

  type decoded_opcode_type is (
    O_NOP,
    O_IM,
    O_LIMR,

    O_ADDI,
    O_ADDRI,
    O_CMPI,

    O_ALU,

    O_ST,
    O_LD,

    -- Branch instructions
    O_BR,
    O_JMP,
    O_JMPE,
    O_SEXTB,
    O_SEXTS,
    -- COP
    O_COPR,
    O_COPW,
    O_RSPR,
    O_WSPR,
    -- Misc
    O_SWI,
    -- Errors
    O_ABORT
  );

  type memory_access_type is (
    M_WORD,
    M_BYTE,
    M_HWORD,
    M_SPR,
    M_WORD_POSTINC,
    M_BYTE_POSTINC,
    M_HWORD_POSTINC,
    M_SPR_POSTINC
  );

  type loadimmtype is (
    LOADNONE,
    LOAD0,
    LOAD8,
    LOAD16,
    LOAD24
  );

  type reg_source_type is (
    reg_source_alu,
    reg_source_memory,
    reg_source_imm,
    reg_source_spr,
    reg_source_pcnext,
    reg_source_cop
  );

  constant JUMP_RI_PCREL: std_logic_vector(1 downto 0) := "00";
  constant JUMP_I_PCREL:  std_logic_vector(1 downto 0) := "01";
  constant JUMP_RI_ABS:   std_logic_vector(1 downto 0) := "11";

  type condition_type is (
    CONDITION_UNCONDITIONAL,
    CONDITION_NE,
    CONDITION_E,
    CONDITION_G,
    CONDITION_GE,
    CONDITION_L,
    CONDITION_LE,
    CONDITION_UG,
    CONDITION_UGE,
    CONDITION_UL,
    CONDITION_ULE,
    CONDITION_S,
    CONDITION_NS
  );


  type opdec_type is record
    modify_gpr:     boolean; -- Modifies GPR
    modify_mem:     boolean; -- Modifies memory (write)
    modify_spr:     boolean; -- Modifies (loads) SPR
    alu_op:         alu_op_type; -- ALU1 operation
    opcode:         opcode_type;  -- The fetched opcode
    opcode_ext:     boolean; -- Extended opcode
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
    condition:      condition_type;
    enable_alu:     std_logic;
    imflag:         std_logic;
    blocks:         std_logic;
    ismult:         std_logic;
    extended:       boolean;
    alu_source:     alu_source_type;
    use_carry:      std_logic;
    -- IMMediate helpers
    imm8l:           std_logic_vector(7 downto 0);
    imm8h:           std_logic_vector(7 downto 0);
    imm24:           std_logic_vector(23 downto 0);
    -- Special reg
    sr:             std_logic_vector(2 downto 0);
    loadimm:        loadimmtype;
    op:             decoded_opcode_type;
    jump:           std_logic_vector(1 downto 0);
    --jump_clause:    jumpcond_type;
    is_jump:        boolean;
    except_return:  boolean;
    cop_en:         std_logic;
    cop_wr:         std_logic;
    cop_id:         std_logic_vector(1 downto 0);
    cop_reg:        std_logic_vector(3 downto 0);
    priv:           std_logic;
  end record;


  type fetchunit_state_type is ( running, jumping, aligning );

  type fetch_regs_type is record
    pc, fpc:        word_type;
    state:          fetchunit_state_type;
    unaligned:      std_logic;
    unaligned_jump: std_logic;
    invert_readout: std_logic;
    qopc:           std_logic_vector(15 downto 0);
  end record;

  type fetch_output_type is record
    r:        fetch_regs_type;
    opcode:   dual_opcode_type;
    valid:    std_logic;
    bothvalid:std_logic;
    inverted: std_logic;
  end record;


  type decode_regs_type is record
    decoded:        decoded_opcode_type;
    valid:          std_logic;
    rd1, rd2:       std_logic;
    sra1, sra2:     regaddress_type;
    opcode:         std_logic_vector(15 downto 0);
    opcode_low:     std_logic_vector(15 downto 0);
    dual:           boolean;
    --dra:            regaddress_type;

    -- Target writeback registers
    reg_source:     reg_source_type;
    regwe:          std_logic;
    dreg:           regaddress_type;
    --reg_source1:    reg_source_type;
    --regwe1:         std_logic;
    --dreg1:          regaddress_type;
    sprwe:          std_logic;
    blocks:         std_logic;
    --blocks2:        std_logic;

    -- FLAGS and flags source
    modify_flags:   boolean;

    --op:             decoded_opcode_type;
    alu_op:         alu_op_type;
    use_carry:      std_logic;
    enable_alu:     std_logic;
    swap_target_reg:std_logic;
    memory_write:   std_logic;
    memory_access:  std_logic;
    la_offset:      unsigned(31 downto 0);
    macc:           memory_access_type;
    wb_is_data_address: std_logic; -- Writeback is data pointer, not alu result
    npc:            word_type;
    fpc:            word_type;
    pc:             word_type;
    tpc:            word_type; -- Trap PC. Might point to the IMM instruction
    condition_clause: condition_type;
    alu_source:     alu_source_type;
    ismult:         std_logic;

    -- IMMediate helpers
    --imm12:          std_logic_vector(11 downto 0);
    --imm8:           std_logic_vector(7 downto 0);
    --imm4:           std_logic_vector(3 downto 0);
    is_jump:        boolean;
    jump:           std_logic_vector(1 downto 0);
    --jump_clause:    jumpcond_type;
    except_return:  boolean;
    delay_slot:     boolean;
    --extended:       boolean;
    imreg:          unsigned(31 downto 0);
    imflag:         std_logic;

    opcode_q:       std_logic_vector(15 downto 0);

    sr:             std_logic_vector(2 downto 0);
    cop_en:         std_logic;
    cop_wr:         std_logic;
    cop_id:         std_logic_vector(1 downto 0);
    cop_reg:        std_logic_vector(3 downto 0);

    priv:           std_logic;
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
    rd1q,rd2q:      std_logic;
    alu:            std_logic;
    waiting:        std_logic;
    alufwa:         std_logic;
    alufwb:         std_logic;
    hold:           std_logic;
    dreg:           regaddress_type;
  end record;

  type fetchdata_output_type is record
    r:                    fetchdata_regs_type;
    rr1,rr2:              word_type_std; -- Register data
    valid:                std_logic;
    alufwa:                std_logic;
    alufwb:                std_logic;
  end record;

  type execute_regs_type is record
    valid:          std_logic;
    wb_is_data_address: std_logic;
    -- Own
    psr:            unsigned(31 downto 0); -- Processor Status register
    spsr:           unsigned(31 downto 0); -- Saved Processor Status register
    alur:           unsigned(31 downto 0);
    sr:             std_logic_vector(2 downto 0);

    dreg:           regaddress_type; -- Destination reg 0
    --dreg1:          regaddress_type; -- Destination reg 1
    regwe:          std_logic; -- Write-enable for destination reg 0
    --regwe1:         std_logic; -- Write-enable for destination reg 1
    reg_source:     reg_source_type; -- Source for destination reg 0
    --reg_source1:    reg_source_type; -- Source for destination reg 1
    alufwa:                std_logic;
    alufwb:                std_logic;

    jump:           std_logic;
    jumpaddr:       word_type;
    trapvector:     word_type;
    trappc:         word_type;
    scratch:        word_type;
    y:              word_type;
    intjmp:         boolean;
    npc:  word_type;
    sprval: word_type;
    trapq: std_logic;
  end record;

  type execute_output_type is record
    r: execute_regs_type;

    -- Async stuff for writeback
    reg_source:   reg_source_type;
    dreg:         regaddress_type;
    regwe:        std_logic;
    executed:     boolean;
    sr:           std_logic_vector(2 downto 0);
    
    alur:   word_type;

    imreg: word_type;
    sprval: word_type;
    sprwe:      std_logic;
    npc:  word_type;
    mwreg:          regaddress_type;    -- Memory writeback register
    macc:           memory_access_type;
    data_write:     std_logic_vector(31 downto 0);
    data_address:   std_logic_vector(31 downto 0);
    data_access:    std_logic;
    data_writeenable: std_logic;

    cop:     std_logic_vector(31 downto 0);
    jump:     std_logic;
    trap:     std_logic;
    clrreg:   std_logic;
    clrhold:  std_logic;
  end record;

  type memory_state_type is (
    midle,
    mbusy
  );

  type memory_regs_type is record
    dreg:                 regaddress_type;
    state:                memory_state_type;
    regwe:            std_logic;
    sprwe:            std_logic;
    macc:           memory_access_type;
    wb_dat:     std_logic_vector(31 downto 0);
    wb_adr:     std_logic_vector(31 downto 0);
    wb_we:      std_logic;
    wb_cyc:     std_logic;
    wb_stb:     std_logic;
    wb_tago:    std_logic_vector(31 downto 0);
    wb_sel:     std_logic_vector(3 downto 0);
    nreq:       unsigned(2 downto 0); --  Number of outstanding requests
  end record;

  type memory_output_type is record
    r:        memory_regs_type;
    mdata:    std_logic_vector(31 downto 0);
    mreg:     regaddress_type;
    mregwe:   std_logic;
    msprwe:   std_logic;
  end record;

  type execute_debug_type is record
    opcode1:    std_logic_vector(15 downto 0);
    opcode2:    std_logic_vector(15 downto 0);
    pc:         word_type;
    dual:       boolean;
    valid:      boolean;
    executed:   boolean;
    lhs:        word_type;
    rhs:        word_type;
  end record;

  type tlb_entry_type is record
    pagesize:   std_logic_vector(1 downto 0);
    ctx:        std_logic_vector(0 downto 0);
    paddr:      std_logic_vector(31 downto 12);
    vaddr:      std_logic_vector(31 downto 12);
    flags:      std_logic_vector(3 downto 0);
  end record;


  type copo is record
    id:   std_logic_vector(1 downto 0);
    reg:  std_logic_vector(3 downto 0);
    data: std_logic_vector(31 downto 0);
    wr:   std_logic;
    en:   std_logic;
  end record;

  type copi is record
    data:   std_logic_vector(31 downto 0);
    valid:  std_logic;
    fault:  std_logic;
  end record;
  
  constant DontCareValue: std_logic := 'X';

  function opcode_txt_pad(strin: in string) return string;
  function regname(r: in regaddress_type) return string;

  subtype slot_id is std_logic_vector(15 downto 0);

  type slot_wbi is array(0 to 15) of wb_miso_type;
  type slot_wbo is array(0 to 15) of wb_mosi_type;
  type slot_ids is array(0 to 15) of slot_id;


  constant ACCESS_WB_WA:      std_logic_vector(1 downto 0) := "00";
  constant ACCESS_WT:         std_logic_vector(1 downto 0) := "01";
  constant ACCESS_WB_NA:      std_logic_vector(1 downto 0) := "10";
  constant ACCESS_NOCACHE:    std_logic_vector(1 downto 0) := "11";

  type dcache_in_type is record
    data:           std_logic_vector(31 downto 0);
    address:        std_logic_vector(31 downto 0);
    tag:            std_logic_vector(31 downto 0);
    accesstype:     std_logic_vector(1 downto 0);
    strobe:         std_logic;
    we:             std_logic;
    wmask:          std_logic_vector(3 downto 0);
    enable:         std_logic;
    flush:          std_logic;
  end record;

  type dcache_out_type is record
    valid:          std_logic;
    data:           std_logic_vector(31 downto 0);
    tag:            std_logic_vector(31 downto 0);
    stall:          std_logic;
    in_flush:       std_logic;
  end record;


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
