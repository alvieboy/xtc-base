#include <stdio.h>
#include <stdlib.h>
#include "opcodes.h"
#include <fcntl.h>
#include "cpu.h"
#include <string.h>

#define UNKNOWN_OP(op) do { printf("Invalid opcode %04x\n", op); abort(); } while (0)

#define IS_IO(x) (x&0x80000000)

const char *opcodeNames[] = {
    "nop",
    "add",
    "addc",
    "sub",
    "subb",
    "and",
    "or",
    "copy",
    "xor",
    "addi",
    "imm",
    "limr",
    "calli",
    "ret",
    "stwi",
    "ldwi"
};

void printOpcode(opcode_t *opcode, FILE *stream)
{
    fprintf(stream,"%s", opcodeNames[opcode->opv]);
}

static int decode_single_opcode(xtc_cpu_t*cpu,unsigned op, opcode_t *opcode)
{

#define IMM8 (cpu->imm<<8) | ((op>>4)&0xff)
#define IMM12 (cpu->imm<<12) | ((op)&0xfff)

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
        default:
            UNKNOWN_OP(op);
        }
        break;
    case 0x2:
        /* Store */
        switch ((op>>8) & 0xf) {
        case 0:
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
        /* Store */
        switch ((op>>8) & 0xf) {
        case 0:
            opcode->opv = OP_LDWI;
            opcode->immed = cpu->imm;
            break;
        default:
            UNKNOWN_OP(op);
        }
        
        break;
    case 0x5:
        UNKNOWN_OP(op);
    case 0x6:
        opcode->opv = OP_ADDI;
        opcode->immed = IMM12;
        break;
    case 0x7:
        UNKNOWN_OP(op);
    case 0x8:
        opcode->opv = OP_IMM;
        opcode->immed = IMM12;
        break;
    case 0x9:
    case 0xA:
    case 0xB:
    case 0xC:
        UNKNOWN_OP(op);
    case 0xD:
        // Calli
        opcode->immed = IMM8;
        opcode->opv = OP_CALLI;
        break;
    case 0xE:
        opcode->opv = OP_LIMR;
        opcode->immed = IMM8;
        break;
    case 0xF:
        opcode->opv = OP_RET;
        break;
    default:
        UNKNOWN_OP(op);
    }
}

static void handle_store(xtc_cpu_t *cpu, unsigned reg_addr, unsigned reg_val, int offset)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;

    if (realaddr < cpu->memsize) {
        cpu->memory[realaddr]=cpu->regs[reg_val];
    } else {
        if (IS_IO(realaddr)) {
            handle_store_io( realaddr, cpu->regs[reg_val] );
        } else {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
}

static cpu_word_t handle_read(xtc_cpu_t *cpu, unsigned reg_addr, int offset)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;

    if (realaddr < cpu->memsize) {
        return cpu->memory[realaddr];
    } else {
        if (IS_IO(realaddr)) {
            return handle_read_io( realaddr );
        } else {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
}

static int execute_single_opcode(xtc_cpu_t *cpu, const opcode_t *opcode)
{
    unsigned npc = cpu->pc+2;

    /*Delay slot*/
    if (cpu->branchNext!=-1)
        npc=cpu->branchNext;

    cpu->branchNext = -1;
    int resetImmed=1;

    switch (opcode->opv) {
    case OP_STWI:
        printf(" r%d, (r%d + %d); (0x%08x)", opcode->r2, opcode->r1, opcode->immed,
               cpu->regs[opcode->r1]+opcode->immed);
        handle_store( cpu, opcode->r1, opcode->r2, opcode->immed);
        break;

    case OP_LDWI:
        printf(" (r%d + %d), r%d; (0x%08x)", opcode->r1, opcode->immed, opcode->r2,
               cpu->regs[opcode->r1]+opcode->immed);
        cpu->regs[opcode->r2] = handle_read( cpu, opcode->r1, opcode->immed);

        break;
    case OP_RET:
        cpu->branchNext = cpu->br;
        break;
    case OP_IMM:
        resetImmed=0;
        printf(" %d", opcode->immed);
        break;

    case OP_CALLI:
        cpu->branchNext = npc + opcode->immed;
        cpu->br = npc + 2;
        break;

    case OP_LIMR:
        cpu->regs[opcode->r1] = opcode->immed;
        printf(" r%d ( <= %08x )", opcode->r1, opcode->immed);
        break;

    case OP_ADDI:
        cpu->regs[opcode->r1] += opcode->immed;
        printf(" %d, r%d ( <= %08x )", opcode->immed, opcode->r1, cpu->regs[opcode->r1] );
        break;

    case OP_ADD:
        cpu->regs[opcode->r1] += cpu->regs[opcode->r2];
        printf(" r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
        break;

    default:
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

xtc_cpu_t *initialize()
{
    xtc_cpu_t *cpu = malloc(sizeof(xtc_cpu_t));
    cpu->memsize = 16384;
    cpu->memory = malloc(cpu->memsize);
    cpu->pc=cpu->br=cpu->y=0;
    cpu->imm = 0;
    cpu->imflag = 0;
    cpu->branchNext = -1;
    memset(cpu->regs, 0, sizeof(cpu->regs));
    return cpu;
}


int execute(xtc_cpu_t *cpu)
{
    do {
        opcode_t opcode;
        inst_t inst = (unsigned)(cpu->memory[cpu->pc]<<8) | cpu->memory[cpu->pc+1];
        decode_single_opcode(cpu,inst,&opcode);
        printf("0x%08x ",cpu->pc);
        printf("0x%04x ",inst);
        printOpcode(&opcode, stdout);
        execute_single_opcode(cpu, &opcode);
        printf("\n");

    }while (1);
}

int run(const char *memfile)
{
    xtc_cpu_t *cpu = initialize();

    int fd = open(memfile,O_RDONLY);
    if (fd<0) {
        perror("Cannot open file");
        return -1;
    }

    read(fd,cpu->memory,cpu->memsize);

    execute(cpu);
}


int main(int argc, char **argv)
{
    return run(argv[1]);
}
