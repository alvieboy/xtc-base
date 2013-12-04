#include "reg_ops.h"

void reg_addi(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    cpu->regs[opcode->r1] += opcode->immed;
    fprintf(stream," %d, r%d ( <= %08x )", opcode->immed, opcode->r1, cpu->regs[opcode->r1] );
}

void reg_imm(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    cpu->resetImmed=0;
    fprintf(stream," %d", opcode->immed);
}

void reg_limr(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    cpu->regs[opcode->r1] = opcode->immed;
    fprintf(stream," r%d ( <= %08x )", opcode->r1, opcode->immed);
}

void reg_cmpi(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    fprintf(stream," %d, r%d", opcode->immed, opcode->r1);
    /* Set flags */
    cpu->zero = (cpu->regs[opcode->r1]==opcode->immed);
    cpu->carry = (cpu->regs[opcode->r1] > opcode->immed);
}

