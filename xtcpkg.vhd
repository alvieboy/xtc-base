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
  constant IO_REGISTER_INPUTS: boolean := true;

  constant TRACECLOCK: boolean := false;
  constant RESETADDRESS: unsigned(31 downto 0) := x"40000000";

  -- Enable low-memory protection.
  constant LOWPROTECTENABLE: boolean := false;
  -- Enable bus/pipeline fault checks.
  constant FAULTCHECKS: boolean := true;
  -- Enable instruction/memory tracer.
  constant TRACER_ENABLED: boolean := false;

  subtype opcode_type is std_logic_vector(15 downto 0);
  subtype dual_opcode_type is std_logic_vector(31 downto 0);
  subtype word_type is unsigned(31 downto 0);
  subtype word_type_std is std_logic_vector(31 downto 0);
  subtype regaddress_type is std_logic_vector(4 downto 0); -- Includes supervisor bit

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
    -- Regbank
    O_RDUSR,
    O_WRUSR,
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
    --reg_source_memory,
    --reg_source_imm,
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
    --modify_mem:     boolean; -- Modifies memory (write)
    modify_spr:     boolean; -- Modifies (loads) SPR
    alu_op:         alu_op_type; -- ALU1 operation
    opcode:         opcode_type;  -- The fetched opcode
    --opcode_ext:     boolean; -- Extended opcode
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
    targetzero:     std_logic;
  end record;


  type fetchunit_state_type is ( running, jumping, aligning );

  type fetch_regs_type is record
    pc, fpc:        word_type;
    state:          fetchunit_state_type;
    unaligned:      std_logic;
    unaligned_jump: std_logic;
    invert_readout: std_logic;
    seq:            std_logic;
    priv:           std_logic;
    qopc:           std_logic_vector(15 downto 0);
  end record;

  type fetch_output_type is record
    r:        fetch_regs_type;
    opcode:   dual_opcode_type;
    valid:    std_logic;
    bothvalid:std_logic;
    inverted: std_logic;
    internalfault: std_logic;
    npc:      word_type;
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
    targetzero:     std_logic;
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
    --swap_target_reg:std_logic;
    memory_write:   std_logic;
    memory_access:  std_logic;
    --la_offset:      unsigned(31 downto 0);
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
    --delay_slot:     boolean;
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

    dreg:           regaddress_type;
    regwe:          std_logic;
    reg_source:     reg_source_type;

    jump:           std_logic;
    jumppriv:        std_logic;
    jumpaddr:       word_type;
    --trapvector:     word_type;
    --trappc:         word_type;
    scratch:        word_type;
    y:              word_type;
    npc:            word_type;
    sprval:         word_type;
    trapq:          std_logic;
    innmi:          std_logic;
    delayslot:      std_logic;
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
    jumppriv: std_logic;
    trap:     std_logic;
    flush:    std_logic;
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
    fault:      std_logic;
    pc:         word_type;
    faddr:      std_logic_vector(31 downto 0);
    nreq:       unsigned(2 downto 0); --  Number of outstanding requests
  end record;

  type memory_output_type is record
    r:        memory_regs_type;
    mdata:    std_logic_vector(31 downto 0);
    mreg:     regaddress_type;
    mregwe:   std_logic;
    msprwe:   std_logic;
    fault:    std_logic;
    internalfault: std_logic;
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
    trap:       std_logic;
    dbgen:      std_logic;
    hold:       std_logic;
    multvalid:  std_logic;
  end record;

  type memory_debug_type is record
    strobe:   std_logic;
    write:    std_logic;
    address:  word_type;
    pc:       word_type;
    data:     word_type;
    faddr:    word_type;
  end record memory_debug_type;

  type tlb_entry_type is record
    pagesize:   std_logic_vector(1 downto 0);
    ctx:        std_logic_vector(0 downto 0);
    paddr:      std_logic_vector(31 downto 12);
    vaddr:      std_logic_vector(31 downto 12);
    flags:      std_logic_vector(3 downto 0);
  end record;

  type copi is record
    reg:  std_logic_vector(3 downto 0);
    data: std_logic_vector(31 downto 0);
    wr:   std_logic;
    en:   std_logic;
  end record;

  type copo is record
    data:   std_logic_vector(31 downto 0);
    valid:  std_logic;
    fault:  std_logic;
  end record;

  type copo_a is array(0 to 3) of copo;
  type copi_a is array(0 to 3) of copi;

  type copifo is record
    id:   std_logic_vector(1 downto 0);
    o:    copi;
  end record;

  type copifi is record
    i:    copo;
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
    err:            std_logic;
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
    variable tmp: string(1 to 4);
  begin
    case r is
      when "00000" => tmp := "UR0 ";
      when "00001" => tmp := "UR1 ";
      when "00010" => tmp := "UR2 ";
      when "00011" => tmp := "UR3 ";
      when "00100" => tmp := "UR4 ";
      when "00101" => tmp := "UR5 ";
      when "00110" => tmp := "UR6 ";
      when "00111" => tmp := "UR7 ";
      when "01000" => tmp := "UR8 ";
      when "01001" => tmp := "UR9 ";
      when "01010" => tmp := "UR10";
      when "01011" => tmp := "UR11";
      when "01100" => tmp := "UR12";
      when "01101" => tmp := "UR13";
      when "01110" => tmp := "UR14";
      when "01111" => tmp := "UR15";
      when "10000" => tmp := "SR0 ";
      when "10001" => tmp := "SR1 ";
      when "10010" => tmp := "SR2 ";
      when "10011" => tmp := "SR3 ";
      when "10100" => tmp := "SR4 ";
      when "10101" => tmp := "SR5 ";
      when "10110" => tmp := "SR6 ";
      when "10111" => tmp := "SR7 ";
      when "11000" => tmp := "SR8 ";
      when "11001" => tmp := "SR9 ";
      when "11010" => tmp := "SR10";
      when "11011" => tmp := "SR11";
      when "11100" => tmp := "SR12";
      when "11101" => tmp := "SR13";
      when "11110" => tmp := "SR14";
      when "11111" => tmp := "SR15";
      when others => tmp := "SR? ";
    end case;
    return tmp;
  end function;
end;
