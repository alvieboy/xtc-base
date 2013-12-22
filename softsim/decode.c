#include <stdio.h>
#include <stdlib.h>

#include "cpu.h"
#include "opcodes.h"
#include "decode.h"

static unsigned get_imm8(xtc_cpu_t *cpu, unsigned op)
{
    if (cpu->imflag) {
        return (cpu->imm<<8) | ((op>>4)&0xff);
    } else {
        if (op & 0x800) {
            // Negative
            return 0xffffff00 | ((op>>4)&0xff);
        } else {
            return (op>>4)&0xff;
        }
    }
}

static unsigned get_imm12(xtc_cpu_t *cpu, unsigned op)
{
    if (cpu->imflag) {
        return (cpu->imm<<12) | ((op)&0xfff);
    } else {
        if (op & 0x800) {
            // Negative
            return 0xfffff000 | ((op)&0xfff);
        } else {
            return (op)&0xfff;
        }
    }
}

int decode_single_opcode(xtc_cpu_t*cpu,unsigned op, opcode_t *opcode)
{

    opcode->op = op;
    opcode->r1 = op & 0xF;
    opcode->r2 = (op>>4) & 0xF;
    opcode->hasImmed=0;
    opcode->alu_op_immed=0;

    switch (op>>12) {
    case 0x0:
        opcode->opv = OP_NOP;
        break;
    case 0x5:
        opcode->immed = cpu->imm;
        opcode->alu_op_immed=1;
        // Fall through
    case 0x1:
        /* ALU operations */
        switch ((op>>8) & 0xf) {
        case 0x0:
            opcode->opv = OP_ADD;
            break;
        case 0x3:
            opcode->opv = OP_SRA;
            break;
        case 0x4:
            opcode->opv = OP_SUB;
            break;
        case 0x8:
            opcode->opv = OP_AND;
            break;
        case 0x9:
            opcode->opv = OP_SRL;
            break;
        case 0xa:
            opcode->opv = OP_OR;
            break;
        case 0xb:
            opcode->opv = OP_XOR;
            break;
        case 0xc:
            opcode->opv = OP_COPY;
            break;
        case 0xf:
            opcode->opv = OP_SHL;
            break;
        case 0xd:
            opcode->opv = OP_CMP;
            break;

        default:
            UNKNOWN_OP(op);
        }
        break;
    case 0x2:
        /* Store */
        switch ((op>>8) & 0x7) {
        case 0:
            opcode->opv = OP_STW;
            opcode->immed = cpu->imm;
            break;
        case 1:
            opcode->opv = OP_STS;
            opcode->immed = cpu->imm;
            break;
        case 2:
            opcode->opv = OP_STB;
            opcode->immed = cpu->imm;
            break;
        case 3:
            opcode->opv = OP_STSPR;
            opcode->immed = cpu->imm;
            break;
        case 4:
            opcode->opv = OP_STWp;
            opcode->immed = cpu->imm;
            break;
        case 5:
            opcode->opv = OP_STSp;
            opcode->immed = cpu->imm;
            break;
        case 6:
            opcode->opv = OP_STBp;
            opcode->immed = cpu->imm;
            break;
        case 7:
            opcode->opv = OP_STSPRp;
            opcode->immed = cpu->imm;
            break;

        default:
            UNKNOWN_OP(op);
        }
        
        break;
    case 0x3:
        UNKNOWN_OP(op);
    case 0x4:
        /* Load */
        opcode->immed = cpu->imm;

        switch ((op>>8) & 0x7) {
        case 0:
            opcode->opv = OP_LDW;
            break;
        case 1:
            opcode->opv = OP_LDS;
            break;
        case 2:
            opcode->opv = OP_LDB;
            break;
        case 3:
            opcode->opv = OP_LDSPR;
            break;
        case 4:
            opcode->opv = OP_LDWp;
            break;
        case 5:
            opcode->opv = OP_LDSp;
            break;
        case 6:
            opcode->opv = OP_LDBp;
            break;
        case 7:
            opcode->opv = OP_LDSPRp;
            break;
        default:
            UNKNOWN_OP(op);
        }
        
        break;
    case 0x6:
        opcode->opv = OP_ADDI;
        opcode->immed = get_imm8(cpu,op);
        break;
    case 0x7:
        opcode->opv = OP_CMPI;
        opcode->immed = get_imm8(cpu,op);
        break;
    case 0x8:
        opcode->opv = OP_IMM;
        opcode->immed = get_imm12(cpu,op);
        break;
    case 0x9:
        // BRI - new format
        opcode->immed = get_imm8(cpu,op);
        opcode->opv = OP_BRI;
        break;
    case 0xA:
        opcode->immed = get_imm8(cpu,op);
        switch (op & 0xf) {
        case 0x0:
            opcode->opv = OP_BRI; // Compat... TODO: remove
            break;
        case 0x8:
            opcode->opv = OP_BRIE;
            break;
        case 0x9:
            opcode->opv = OP_BRINE;
            break;
        case 0xa:
            opcode->opv = OP_BRIGT;
            break;
        case 0xb:
            opcode->opv = OP_BRIGE;
            break;
        case 0xc:
            opcode->opv = OP_BRILT;
            break;
        case 0xd:
            opcode->opv = OP_BRILE;
            break;
        case 0xe:
            opcode->opv = OP_BRIUGT;
            break;
        case 0x1:
            opcode->opv = OP_BRIULT;
            break;

        default:
            UNKNOWN_OP(op);
        }
        break;
    case 0xB:
    case 0xC:
        UNKNOWN_OP(op);
    case 0xD:
        // Calli
        opcode->immed = get_imm8(cpu,op);
        opcode->opv = OP_CALLI;
        break;
    case 0xE:
        opcode->opv = OP_LIMR;
        opcode->immed = get_imm8(cpu,op);
        break;
    case 0xF:
        opcode->opv = OP_RET;
        break;
    default:
        UNKNOWN_OP(op);
    }
    return 0;
}
