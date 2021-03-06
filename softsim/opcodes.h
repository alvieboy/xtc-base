#ifndef __OPCODES_H__
#define __OPCODES_H__

typedef enum {
    OP_NOP,
    OP_ADD,
    OP_ADDC,
    OP_SUB,
    OP_SUBB,
    OP_AND,
    OP_OR,
    OP_COPY,
    OP_XOR,
    OP_SRA,
    OP_SRL,
    OP_SHL,
    OP_MUL,
    OP_CMP,
    OP_ADDI,
    OP_IMM,
    OP_LIMR,
    OP_CALLI,
    OP_RET,

    OP_STW,
    OP_STS,
    OP_STB,
    OP_STSPR,
    OP_STWp,
    OP_STSp,
    OP_STBp,
    OP_STSPRp,

    OP_LDW,
    OP_LDS,
    OP_LDB,
    OP_LDSPR,
    OP_LDWp,
    OP_LDSp,
    OP_LDBp,
    OP_LDSPRp,

    OP_BRI,
    OP_BRIE,
    OP_BRINE,
    OP_BRILT,
    OP_BRILE,
    OP_BRIGT,
    OP_BRIGE,
    OP_BRIUGT,
    OP_BRIULT,
    OP_BRIUGE,
    OP_BRIULE,
    OP_CMPI,

    MAX_OPCODES
} opcode_type_t;


typedef struct opcode {
    opcode_type_t opv;
    unsigned r1,r2;
    int hasImmed;
    int immed;
    unsigned op;
    int alu_op_immed;
} opcode_t;


#endif
