#include <stdio.h>
#include <stdlib.h>
#include "opcodes.h"
#include <fcntl.h>
#include "cpu.h"
#include <string.h>

#define UNKNOWN_OP(op) do { printf("Invalid opcode %04x, PC 0x%08x\n", op,cpu->pc); abort(); } while (0)

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
    "sra",
    "srl",
    "shl",
    "cmp",
    "addi",
    "imm",
    "limr",
    "calli",
    "ret",
    "stwi",
    "sts",
    "stb",
    "ldwi",
    "ld+w",
    "ldw+",
    "ld-w",
    "ld+w",
    "lds",
    "ld+s",
    "lds+",
    "ldb",
    "ld+b",
    "ldb+",
    "bri",
    "brieq",
    "brine",
    "brilt",
    "brigt",
    "briugt",
    "cmpi"
};

void printOpcode(opcode_t *opcode, FILE *stream)
{
    fprintf(stream,"%s", opcodeNames[opcode->opv]);
}

uint32_t xtc_read_mem_u32(unsigned char *addr){
    uint32_t r;
    r = ((uint32_t)(*addr++))<<24;
    r+= ((uint32_t)(*addr++))<<16;
    r+= ((uint32_t)(*addr++))<<8;
    r+= ((uint32_t)(*addr));
    return r;
}

uint16_t xtc_read_mem_u16(unsigned char *addr){
    uint16_t r;
    r= ((uint16_t)(*addr++))<<8;
    r+= ((uint16_t)(*addr));
    return r;
}

uint8_t xtc_read_mem_u8(unsigned char *addr) {
    uint8_t r;
    r = ((uint8_t)(*addr));
    return r;

}

void xtc_store_mem_u32(unsigned char *addr, uint32_t val)
{
    *addr++ = val>>24;
    *addr++ = val>>18;
    *addr++ = val>>8;
    *addr = val;
}
void xtc_store_mem_u16(unsigned char *addr, uint16_t val)
{
    *addr++ = val>>8;
    *addr = val;
}
void xtc_store_mem_u8(unsigned char *addr, uint8_t val)
{
    *addr = val;
}



static void handle_store(xtc_cpu_t *cpu, unsigned reg_addr, unsigned reg_val, int offset)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;
    realaddr &= ~3;

    if (realaddr < cpu->memsize) {
        xtc_store_mem_u32( &cpu->memory[realaddr], cpu->regs[reg_val]);
    } else {
        if (IS_IO(realaddr)) {
            handle_store_io( realaddr, cpu->regs[reg_val] );
        } else {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
}

static void handle_store_short(xtc_cpu_t *cpu, unsigned reg_addr, unsigned reg_val, int offset)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;
    realaddr &= ~1;

    if (realaddr < cpu->memsize) {
        xtc_store_mem_u16( &cpu->memory[realaddr], cpu->regs[reg_val]);
    } else {
        if (IS_IO(realaddr)) {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
}

static void handle_store_byte(xtc_cpu_t *cpu, unsigned reg_addr, unsigned reg_val, int offset)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;
    if (realaddr < cpu->memsize) {
        xtc_store_mem_u8( &cpu->memory[realaddr], cpu->regs[reg_val]);
    } else {
        if (IS_IO(realaddr)) {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
}

static cpu_word_t handle_read(xtc_cpu_t *cpu, unsigned reg_addr, int offset)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;
    realaddr &= ~3;

    if (realaddr < cpu->memsize) {
        return xtc_read_mem_u32( &cpu->memory[realaddr]);
    } else {
        if (IS_IO(realaddr)) {
            return handle_read_io( realaddr );
        } else {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
}

static cpu_word_t handle_read_short(xtc_cpu_t *cpu, unsigned reg_addr, int offset)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;
    realaddr &= ~1;

    if (realaddr < cpu->memsize) {
        return xtc_read_mem_u16( &cpu->memory[realaddr]);
    } else {
        if (IS_IO(realaddr)) {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
}
static cpu_word_t handle_read_byte(xtc_cpu_t *cpu, unsigned reg_addr, int offset)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;

    if (realaddr < cpu->memsize) {
        return xtc_read_mem_u8( &cpu->memory[realaddr]);
    } else {
        if (IS_IO(realaddr)) {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
}


static unsigned get_imm8(xtc_cpu_t *cpu, unsigned op)
{
    if (cpu->imflag) {
        return (cpu->imm<<8) | ((op>>4)&0xff);
    } else {
        if (op & 0x800) {
            // Negative
            return 0xffffff00 | (op>>4)&0xff;
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
            return 0xfffff000 | (op)&0xfff;
        } else {
            return (op)&0xfff;
        }
    }
}

static int decode_single_opcode(xtc_cpu_t*cpu,unsigned op, opcode_t *opcode)
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
        switch ((op>>8) & 0xf) {
        case 0:
        case 0xb: // Remove later
            opcode->opv = OP_STWI;
            opcode->immed = cpu->imm;
            break;

        case 5:
        case 0xc: // Remove later
            opcode->opv = OP_STS;
            opcode->immed = cpu->imm;
            break;

        case 8:
        case 0xd: // Remove later
            opcode->opv = OP_STB;
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
        case 0xc:
            opcode->opv = OP_BRILT;
            break;
        case 0xe:
            opcode->opv = OP_BRIUGT;
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
    case OP_STWI:
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

    case OP_LDWI:
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
        UNKNOWN_OP(opcode->op);
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
        execute_single_opcode(cpu, &opcode, trace);
        fprintf(trace,"\n");

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
