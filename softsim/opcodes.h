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
    OP_ADDI,
    OP_IMM,
    OP_LIMR,
    OP_CALLI,
    OP_RET,
    OP_STWI,
    OP_LDWI
} opcode_type_t;


typedef struct opcode {
    opcode_type_t opv;
    unsigned r1,r2;
    int hasImmed;
    int immed;
} opcode_t;

#endif
