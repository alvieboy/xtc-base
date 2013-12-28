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
    fprintf(stream," %d, r%d ( <= %08x )", opcode->immed, opcode->r1, opcode->immed);
}

void reg_cmpi(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    fprintf(stream," %d, r%d", opcode->immed, opcode->r1);
    /* Set flags.
     The operation is similar to

     R = R - imm
     */
    fprintf(stream," =%08x (%d) ",cpu->regs[opcode->r1],(int)cpu->regs[opcode->r1]);

    unsigned long long subr = (unsigned long long)cpu->regs[opcode->r1] -
        (unsigned long long)opcode->immed;

    /* Set flags */

    cpu->zero = (subr == 0);
    cpu->carry = !!(subr & 0x100000000);
    cpu->sign = !!(subr &   0x80000000);

    fprintf(stream," (flags Z=%d C=%d S=%d)", cpu->zero, cpu->carry, cpu->sign);
}

