#include <stdio.h>
#include <stdlib.h>
#include "opcodes.h"
#include <fcntl.h>
#include "cpu.h"
#include <string.h>

#include "cpu.h"
#include "opcodes.h"
#include "decode.h"
#include "memory.h"
#include "executor.h"
#include "alu_ops.h"
#include "cflow_ops.h"
#include "mem_ops.h"
#include "reg_ops.h"

/** @brief function pointer declaration for instruction handlers
 */
typedef void(*inst_handler_t)(xtc_cpu_t *cpu,
                              const opcode_t *opcode,
                              FILE *stream);

/** @brief Structure that holds instruction handler function pointers
 */
typedef struct inst_handling
{
      opcode_type_t opcode;
      char *opcode_name;
      inst_handler_t handler;
} inst_handling_t;


const inst_handling_t opc_handling[] = {
    /* OP_NOP    */ {OP_NOP,    "nop",    0},
    /* OP_ADD    */ {OP_ADD,    "add",    alu_add},
    /* OP_ADDC   */ {OP_ADDC,   "addc",   alu_addc},
    /* OP_SUB    */ {OP_SUB,    "sub",    alu_sub},
    /* OP_SUBB   */ {OP_SUBB,   "subb",   alu_subb},
    /* OP_AND    */ {OP_AND,    "and",    alu_and},
    /* OP_OR     */ {OP_OR,     "or",     alu_or},
    /* OP_COPY   */ {OP_COPY,   "copy",   alu_copy},
    /* OP_XOR    */ {OP_XOR,    "xor",    alu_xor},
    /* OP_SRA    */ {OP_SRA,    "sra",    alu_sra},
    /* OP_SRL    */ {OP_SRL,    "srl",    alu_srl},
    /* OP_SHL    */ {OP_SHL,    "shl",    alu_shl},
    /* OP_CMP    */ {OP_CMP,    "cmp",    alu_cmp},
    /* OP_ADDI   */ {OP_ADDI,   "addi",   reg_addi},
    /* OP_IMM    */ {OP_IMM,    "imm",    reg_imm},
    /* OP_LIMR   */ {OP_LIMR,   "limr",   reg_limr},
    /* OP_CALLI  */ {OP_CALLI,  "calli",  cflow_calli},
    /* OP_RET    */ {OP_RET,    "ret",    cflow_ret},

    /* OP_STW    */ {OP_STW,    "stw",    mem_stw},
    /* OP_STS    */ {OP_STS,    "sts",    mem_sts},
    /* OP_STB    */ {OP_STB,    "stb",    mem_stb},
    /* OP_STSPR  */ {OP_STSPR,  "stspr",  mem_stspr},
    /* OP_STWp   */ {OP_STWp,   "stw+",   mem_stwp},
    /* OP_STSp   */ {OP_STSp,   "sts+",   mem_stsp},
    /* OP_STBp   */ {OP_STBp,   "stb+",   mem_stbp},
    /* OP_STSPRp */ {OP_STSPRp, "stspr+", mem_stsprp},

    /* OP_LDW    */ {OP_LDW,    "ldw",    mem_ldw},
    /* OP_LDS    */ {OP_LDS,    "lds",    mem_lds},
    /* OP_LDB    */ {OP_LDB,    "ldb",    mem_ldb},
    /* OP_LDSPR  */ {OP_LDSPR,  "ldspr",  mem_ldspr},
    /* OP_LDWp   */ {OP_LDWp,   "ldw+",   mem_ldwp},
    /* OP_LDSp   */ {OP_LDSp,   "lds+",   mem_ldsp},
    /* OP_LDBp   */ {OP_LDBp,   "ldb+",   mem_ldbp},
    /* OP_LDSPRp */ {OP_LDSPRp, "ldspr+", mem_ldsprp},

    /* OP_BRI    */ {OP_BRI,    "bri",    cflow_bri},
    /* OP_BRIE   */ {OP_BRIE,   "brieq",  cflow_brie},
    /* OP_BRINE  */ {OP_BRINE,  "brine",  cflow_brine},
    /* OP_BRILT  */ {OP_BRILT,  "brilt",  cflow_brilt},
    /* OP_BRIGT  */ {OP_BRIGT,  "brigt",  cflow_brigt},
    /* OP_BRIUGT */ {OP_BRIUGT, "briugt", cflow_briugt},
    /* OP_CMPI   */ {OP_CMPI,   "cmpi",   reg_cmpi}
};

void printOpcode(opcode_t *opcode, FILE *stream)
{
    fprintf(stream,"%s", opc_handling[opcode->opv].opcode_name);
}


static int execute_single_opcode(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream)
{
    unsigned npc = cpu->pc+2;

    /*Delay slot*/
    if (cpu->branchNext!=-1) {
        npc=cpu->branchNext;
    }

    cpu->branchNext = -1;
    int resetImmed=1;

    switch (opcode->opv) {
    case OP_STW:
        fprintf(stream," r%d, (r%d + %d); (0x%08x)", opcode->r2, opcode->r1, opcode->immed,
               cpu->regs[opcode->r1]+opcode->immed);
        handle_store( cpu, opcode->r1, opcode->r2, opcode->immed);
        break;

    case OP_STS:
        fprintf(stream," r%d, (r%d + %d); (0x%08x)", opcode->r2, opcode->r1, opcode->immed,
               cpu->regs[opcode->r1]+opcode->immed);
        handle_store_short( cpu, opcode->r1, opcode->r2, opcode->immed);
        break;

    case OP_STB:
        fprintf(stream," r%d, (r%d + %d); (0x%08x)", opcode->r2, opcode->r1, opcode->immed,
               cpu->regs[opcode->r1]+opcode->immed);
        handle_store_byte( cpu, opcode->r1, opcode->r2, opcode->immed);
        break;

    case OP_LDW:
        fprintf(stream," (r%d + %d), r%d; (0x%08x)", opcode->r1, opcode->immed, opcode->r2,
               cpu->regs[opcode->r1]+opcode->immed);
        cpu->regs[opcode->r2] = handle_read( cpu, opcode->r1, opcode->immed);

        break;

    case OP_LDBp:
        fprintf(stream," (r%d + %d), r%d; (0x%08x)", opcode->r1, opcode->immed, opcode->r2,
               cpu->regs[opcode->r1]+opcode->immed);
        cpu->regs[opcode->r2] = handle_read_byte( cpu, opcode->r1, opcode->immed);
        cpu->regs[opcode->r1]++;

        break;

    case OP_LDB:
        fprintf(stream," (r%d + %d), r%d; (0x%08x)", opcode->r1, opcode->immed, opcode->r2,
               cpu->regs[opcode->r1]+opcode->immed);
        cpu->regs[opcode->r2] = handle_read_byte( cpu, opcode->r1, opcode->immed);
        break;

    case OP_RET:
        cpu->branchNext = cpu->br;
        break;
    case OP_IMM:
        resetImmed=0;
        fprintf(stream," %d", opcode->immed);
        break;

    case OP_CALLI:
        cpu->branchNext = npc + opcode->immed;
        cpu->br = npc + 2;
        break;

    case OP_BRI:
        cpu->branchNext = npc + opcode->immed;
        break;

    case OP_BRIE:
        if (cpu->zero)
            cpu->branchNext = npc + opcode->immed;
        break;

    case OP_BRINE:
        if (!cpu->zero)
            cpu->branchNext = npc + opcode->immed;
        break;

    case OP_BRILT:
        if (!cpu->carry && !cpu->zero)
            cpu->branchNext = npc + opcode->immed;
        break;

    case OP_BRIGT:
        // TODO: sign
        if (cpu->carry)
            cpu->branchNext = npc + opcode->immed;
        break;

    case OP_BRIUGT:
        // TODO: sign
        if (cpu->carry)
            cpu->branchNext = npc + opcode->immed;
        break;

    case OP_LIMR:
        cpu->regs[opcode->r1] = opcode->immed;
        fprintf(stream," %d, r%d ( <= %08x )", opcode->immed, opcode->r1, opcode->immed);
        break;

    case OP_ADDI:
        cpu->regs[opcode->r1] += opcode->immed;
        fprintf(stream," %d, r%d ( <= %08x )", opcode->immed, opcode->r1, cpu->regs[opcode->r1] );
        break;

    case OP_COPY:
        cpu->regs[opcode->r1] = cpu->regs[opcode->r2];
        fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
        break;

    case OP_ADD:
        cpu->regs[opcode->r1] += cpu->regs[opcode->r2];
        fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
        break;

    case OP_SRL:
        cpu->regs[opcode->r1] >>= cpu->regs[opcode->r2];
        fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
        break;

    case OP_SHL:
        cpu->regs[opcode->r1] <<= cpu->regs[opcode->r2];
        fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
        break;

    case OP_SRA:
        cpu->regs[opcode->r1] = (cpu_word_t)( (int) cpu->regs[opcode->r1]  >> cpu->regs[opcode->r2]);
        fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
        break;

    case OP_AND:
        cpu->regs[opcode->r1] &= cpu->regs[opcode->r2];
        fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
        /* Set flags */
        cpu->zero = (cpu->regs[opcode->r1]==0);
        cpu->carry = 0;
        break;

    case OP_OR:
        cpu->regs[opcode->r1] |= cpu->regs[opcode->r2];
        fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
        /* Set flags */
        cpu->zero = (cpu->regs[opcode->r1]==0);
        cpu->carry = 0;
        break;

    case OP_CMP:
        fprintf(stream," r%d, r%d", opcode->r2, opcode->r1);
        /* Set flags */
        cpu->zero = (cpu->regs[opcode->r1] == cpu->regs[opcode->r2]);
        cpu->carry = (cpu->regs[opcode->r1] > cpu->regs[opcode->r2]);
        break;

    case OP_SUB:
        cpu->regs[opcode->r1] -= cpu->regs[opcode->r2];
        fprintf(stream," r%d, r%d", opcode->r2, opcode->r1);
        /* Set flags */
        cpu->zero = (cpu->regs[opcode->r1] == cpu->regs[opcode->r2]);
        cpu->carry = (cpu->regs[opcode->r1] > cpu->regs[opcode->r2]);
        break;

    case OP_CMPI:
        fprintf(stream," %d, r%d", opcode->immed, opcode->r1);
        /* Set flags */
        cpu->zero = (cpu->regs[opcode->r1]==opcode->immed);
        cpu->carry = (cpu->regs[opcode->r1] > opcode->immed);
        break;

    case OP_NOP:
        break;
    default:
        UNHANDLED_OP(opc_handling[opcode->opv].opcode_name, opcode->op);
        break;
    }


    if ( resetImmed ) {
        cpu->imm=0;
        cpu->imflag=0;
    } else {
        cpu->imm=opcode->immed;
        cpu->imflag=1;
    }

    cpu->pc=npc;
}

static int execute_single_opcode_new(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream)
{
    cpu->npc = cpu->pc+2;

    /*Delay slot*/
    if (cpu->branchNext!=-1) {
        cpu->npc=cpu->branchNext;
    }

    cpu->branchNext = -1;
    cpu->resetImmed=1;


    if (opcode->opv == OP_NOP)
    {
        /* Do nothing to nopeit out*/
    }
    else if (opcode->opv > OP_NOP && opcode->opv <= OP_CMPI)
    {
        opc_handling[opcode->opv].handler(cpu, opcode, stream);
    }
    else {
        UNKNOWN_OP(opcode->op);
    }

    if ( cpu->resetImmed ) {
        cpu->imm=0;
        cpu->imflag=0;
    } else {
        cpu->imm=opcode->immed;
        cpu->imflag=1;
    }

    cpu->pc=cpu->npc;
    return 0;
}


int execute(xtc_cpu_t *cpu)
{
    FILE *trace = fopen("trace.txt","w");
    if (NULL==trace) {
        perror("fopen");
        return -1;
    }
    do {
        opcode_t opcode;
        inst_t inst = (unsigned)(cpu->memory[cpu->pc]<<8) | cpu->memory[cpu->pc+1];
        decode_single_opcode(cpu,inst,&opcode);
        fprintf(trace,"0x%08x ",cpu->pc);
        fprintf(trace,"0x%04x ",inst);
        printOpcode(&opcode, trace);
        execute_single_opcode_new(cpu, &opcode, trace);
        fprintf(trace,"\n");

    }while (1);
}
