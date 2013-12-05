#include <stdlib.h>

#include "alu_ops.h"
#include "decode.h"


void alu_add(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    cpu->regs[opcode->r1] += cpu->regs[opcode->r2];
    fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
}

void alu_addc(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    UNHANDLED_OP("addc", opcode->op);
}

void alu_sub(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    cpu->regs[opcode->r1] -= cpu->regs[opcode->r2];
    fprintf(stream," r%d, r%d", opcode->r2, opcode->r1);
    /* Set flags */
    cpu->zero = (cpu->regs[opcode->r1] == cpu->regs[opcode->r2]);
    cpu->carry = (cpu->regs[opcode->r1] > cpu->regs[opcode->r2]);
}

void alu_subb(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    UNHANDLED_OP("subb", opcode->op);
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
    cpu->regs[opcode->r1] = cpu->regs[opcode->r2];
    fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
}

void alu_xor(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    UNHANDLED_OP("xor", opcode->op);
}

void alu_sra(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    cpu->regs[opcode->r1] = (cpu_word_t)( (int) cpu->regs[opcode->r1]  >> cpu->regs[opcode->r2]);
    fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
}

void alu_srl(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    cpu->regs[opcode->r1] >>= cpu->regs[opcode->r2];
    fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
}

void alu_shl(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    cpu->regs[opcode->r1] <<= cpu->regs[opcode->r2];
    fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
}

void alu_cmp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    fprintf(stream," r%d, r%d", opcode->r2, opcode->r1);
    /* Set flags */
    cpu->zero = (cpu->regs[opcode->r1] == cpu->regs[opcode->r2]);
    cpu->carry = (cpu->regs[opcode->r1] > cpu->regs[opcode->r2]);
}


