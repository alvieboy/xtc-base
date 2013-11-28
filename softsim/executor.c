#include <stdio.h>
#include <stdlib.h>
#include "opcodes.h"
#include <fcntl.h>
#include "cpu.h"
#include <string.h>

#define UNKNOWN_OP(op) do { printf("Invalid opcode %04x\n", op); abort(); } while (0)

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
    "calli"
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
    opcode->r2 = (op>>8) & 0xF;
    opcode->hasImmed=0;

    switch (op>>12) {
    case 0x0:
        opcode->opv = OP_NOP;
        break;
    case 0x1:
        /* ALU operations */
        switch ((op>>8) &0xf) {
        case 0x0:
            opcode->opv = OP_ADD;
            break;
        default:
            UNKNOWN_OP(op);
        }
    case 0x2:
    case 0x3:
    case 0x4:
    case 0x5:
    case 0x6:
    case 0x7:
    case 0x8:
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
    default:
        UNKNOWN_OP(op);
    }
}

static int execute_single_opcode(xtc_cpu_t *cpu, const opcode_t *opcode)
{
    unsigned npc = cpu->pc+2;
    int resetImmed=1;

    switch (opcode->opv) {
    case OP_CALLI:
        npc += opcode->immed;
        break;

    case OP_LIMR:
        cpu->regs[opcode->r1] = opcode->immed;
        printf(" r%d ( <= %08x )", opcode->r1, opcode->immed);
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
