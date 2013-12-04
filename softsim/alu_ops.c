#include <stdlib.h>

#include "alu_ops.h"
#include "opcodes.h"


void alu_add(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    cpu->regs[opcode->r1] += cpu->regs[opcode->r2];
    fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
}

void alu_addc(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    NOT_IMPLEMENT_OP(opcode->op);
}

void alu_sub(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    NOT_IMPLEMENT_OP(opcode->op);
}

void alu_subb(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    NOT_IMPLEMENT_OP(opcode->op);
}

void alu_and(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    cpu->regs[opcode->r1] &= cpu->regs[opcode->r2];
    fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
    /* Set flags */
    cpu->zero = (cpu->regs[opcode->r1]==0);
    cpu->carry = 0;
}

void alu_or(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    cpu->regs[opcode->r1] |= cpu->regs[opcode->r2];
    fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
    /* Set flags */
    cpu->zero = (cpu->regs[opcode->r1]==0);
    cpu->carry = 0;
}

void alu_copy(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    cpu->regs[opcode->r1] = opcode->immed;
    fprintf(stream," %d, r%d ( <= %08x )", opcode->immed, opcode->r1, cpu->regs[opcode->r1] );
}

void alu_xor(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    NOT_IMPLEMENT_OP(opcode->op);
}

