#include <stdio.h>
#include <stdlib.h>

#include "cpu.h"
#include "opcodes.h"
#include "decode.h"

static unsigned get_imm8(xtc_cpu_t *cpu, unsigned op)
{
    if (cpu->imflag) {
        return ((cpu->imm<<8) | ((op>>4)&0xff));
    } else {
        if (op & 0x800) {
            // Negative
            return (0xffffff00 | ((op>>4)&0xff));
        } else {
            return (op>>4)&0xff;
        }
    }
}

static unsigned get_imm12(xtc_cpu_t *cpu, unsigned op)
{
    if (cpu->imflag) {
        return ((cpu->imm<<12) | ((op)&0xfff));
    } else {
        if (op & 0x800) {
            // Negative
            return (0xfffff000 | ((op)&0xfff));
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

    switch (op>>12) {
    case 0x0:
        opcode->opv = OP_NOP;
        break;
    case 0x1:
        /* ALU operations */
        switch ((op>>8) & 0xf) {
        case 0x0:
            opcode->opv = OP_ADD;
            break;
        case 0x8:
            opcode->opv = OP_AND;
            break;
        case 0x9:
            opcode->opv = OP_AND;
            break;
        case 0xa:
            opcode->opv = OP_OR;
            break;
        case 0xc:
            opcode->opv = OP_COPY;
            break;

        default:
            UNKNOWN_OP(op);
        }
        break;
    case 0x2:
        /* Store */
        switch ((op>>8) & 0xf) {
        case 0:
        case 0xb: // Remove later
            opcode->opv = OP_STWI;
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

        switch ((op>>8) & 0xf) {
        case 0:
        case 0xb: // This will be removed later
            opcode->opv = OP_LDWI;
            break;
        case 1:
            opcode->opv = OP_LDpW;
            break;
        case 2:
            opcode->opv = OP_LDWp;
            break;
        case 3:
            opcode->opv = OP_LDmW;
            break;
        case 4:
            opcode->opv = OP_LDWm;
            break;
        case 5:
        case 0xc: // Remove later
            opcode->opv = OP_LDS;
            break;
        case 6:
            opcode->opv = OP_LDpS;
            break;
        case 7:
            opcode->opv = OP_LDSp;
            break;
        case 8:
        case 0xd: // Remove later
            opcode->opv = OP_LDB;
            break;
        case 9:
            opcode->opv = OP_LDpB;
            break;
        case 0xa:
            opcode->opv = OP_LDBp;
            break;

        default:
            UNKNOWN_OP(op);
        }
        
        break;
    case 0x5:
        UNKNOWN_OP(op);
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
        UNKNOWN_OP(op);
    case 0xA:
        opcode->immed = get_imm8(cpu,op);
        switch (op & 0xf) {
        case 0x0:
            opcode->opv = OP_BRI;
            break;
        case 0x8:
            opcode->opv = OP_BRIE;
            break;
        case 0x9:
            opcode->opv = OP_BRINE;
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
