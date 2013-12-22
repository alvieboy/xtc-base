#include <stdlib.h>

#include "alu_ops.h"
#include "decode.h"



void alu_add(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    int operand = opcode->alu_op_immed ? opcode->immed : cpu->regs[opcode->r1];
    cpu->regs[opcode->r1] = cpu->regs[opcode->r2] + operand;
    fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
}

void alu_addc(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    UNHANDLED_OP("addc", opcode->op);
}

void alu_sub(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    int operand = opcode->alu_op_immed ? opcode->immed : cpu->regs[opcode->r2];

    cpu->regs[opcode->r1] = cpu->regs[opcode->r1] - operand;

    fprintf(stream," r%d, r%d ( <= %08x)", opcode->r2, opcode->r1,
           cpu->regs[opcode->r1]);
    /* Set flags */
    cpu->zero = (cpu->regs[opcode->r1] == cpu->regs[opcode->r2]);
    cpu->carry = (cpu->regs[opcode->r1] > cpu->regs[opcode->r2]);
}

void alu_subb(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    UNHANDLED_OP("subb", opcode->op);
}

void alu_and(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    int operand = opcode->alu_op_immed ? opcode->immed : cpu->regs[opcode->r1];
    cpu->regs[opcode->r1] = cpu->regs[opcode->r2] & operand;
    fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
    /* Set flags */
    cpu->zero = (cpu->regs[opcode->r1]==0);
    cpu->carry = 0;
}

void alu_or(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    int operand = opcode->alu_op_immed ? opcode->immed : cpu->regs[opcode->r1];
    cpu->regs[opcode->r1] = cpu->regs[opcode->r2] | operand;
    fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
    /* Set flags */
    cpu->zero = (cpu->regs[opcode->r1]==0);
    cpu->carry = 0;
}

void alu_copy(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    // TODO: deprecate
    cpu->regs[opcode->r1] = cpu->regs[opcode->r2];
    fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
}

void alu_xor(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    int operand = opcode->alu_op_immed ? opcode->immed : cpu->regs[opcode->r1];
    cpu->regs[opcode->r1] = cpu->regs[opcode->r2]  ^ operand;
    fprintf(stream," r%d, r%d ( <= %08x )", opcode->r2, opcode->r1, cpu->regs[opcode->r1] );
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

    fprintf(stream," r%d, r%d (0x%08x, 0x%08x)", opcode->r2, opcode->r1,
           cpu->regs[opcode->r2], cpu->regs[opcode->r1]
           );

    /* Set flags */

    cpu->zero = (cpu->regs[opcode->r1]==cpu->regs[opcode->r2]);

    cpu->ovf = ((int)cpu->regs[opcode->r1] > cpu->regs[opcode->r2]);

    cpu->carry = ((unsigned)(cpu->regs[opcode->r1]) > (unsigned)(cpu->regs[opcode->r2]));

    cpu->sign = !!((cpu->regs[opcode->r1] - (unsigned)cpu->regs[opcode->r2]) & 0x80000000);

    fprintf(stream," (flags Z=%d C=%d S=%d O=%d)", cpu->zero, cpu->carry, cpu->sign, cpu->ovf);

}


