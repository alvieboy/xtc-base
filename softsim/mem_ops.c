#include <stdlib.h>

#include "mem_ops.h"
#include "memory.h"


void mem_stwi(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {

    fprintf(stream," r%d, (r%d + %d); (0x%08x)", opcode->r2, opcode->r1, opcode->immed,
               cpu->regs[opcode->r1]+opcode->immed);
    handle_store( cpu, opcode->r1, opcode->r2, opcode->immed);
}

void mem_ldwi(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    fprintf(stream," (r%d + %d), r%d; (0x%08x)", opcode->r1, opcode->immed, opcode->r2,
               cpu->regs[opcode->r1]+opcode->immed);
    cpu->regs[opcode->r2] = handle_read( cpu, opcode->r1, opcode->immed);
}

void mem_ldpw(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    NOT_IMPLEMENT_OP(opcode->op);
}

void mem_ldwp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    NOT_IMPLEMENT_OP(opcode->op);
}

void mem_ldmw(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    NOT_IMPLEMENT_OP(opcode->op);
}

void mem_ldwm(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    NOT_IMPLEMENT_OP(opcode->op);
}

void mem_lds(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    NOT_IMPLEMENT_OP(opcode->op);
}

void mem_ldps(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    NOT_IMPLEMENT_OP(opcode->op);
}

void mem_ldsp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    NOT_IMPLEMENT_OP(opcode->op);
}

void mem_ldb(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    fprintf(stream," (r%d + %d), r%d; (0x%08x)", opcode->r1, opcode->immed, opcode->r2,
           cpu->regs[opcode->r1]+opcode->immed);
    cpu->regs[opcode->r2] = handle_read_byte( cpu, opcode->r1, opcode->immed);
}

void mem_ldpb(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    NOT_IMPLEMENT_OP(opcode->op);
}

void mem_ldbp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    fprintf(stream," (r%d + %d), r%d; (0x%08x)", opcode->r1, opcode->immed, opcode->r2,
               cpu->regs[opcode->r1]+opcode->immed);

    cpu->regs[opcode->r2] = handle_read_byte( cpu, opcode->r1, opcode->immed);
    cpu->regs[opcode->r1]++;
}

