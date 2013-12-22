#include <stdlib.h>

#include "mem_ops.h"
#include "memory.h"
#include "decode.h"
#include "cpu.h"

void mem_stw(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    fprintf(stream," r%d, (r%d + %d)", opcode->r2, opcode->r1, opcode->immed);
    handle_store( cpu, opcode->r1, opcode->r2, opcode->immed, stream);
}

void mem_sts(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    fprintf(stream," r%d, (r%d + %d)", opcode->r2, opcode->r1, opcode->immed);
    handle_store_short( cpu, opcode->r1, opcode->r2, opcode->immed, stream);
}

void mem_stb(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    fprintf(stream," r%d, (r%d + %d)", opcode->r2, opcode->r1, opcode->immed);
    handle_store_byte( cpu, opcode->r1, opcode->r2, opcode->immed, stream);
}

void mem_stspr(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    cpu_word_t val = xtc_get_spr(cpu, opcode->r2);
    fprintf(stream, " spr%d, (r%d + %d)", opcode->r2, opcode->r1, opcode->immed);
    handle_store_val(cpu, opcode->r1, val, opcode->immed, stream);
}

void mem_stwp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    UNHANDLED_OP("stwp", opcode->op);
}

void mem_stsp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    UNHANDLED_OP("stsp", opcode->op);
}

void mem_stbp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    UNHANDLED_OP("stbp", opcode->op);
}

void mem_stsprp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    UNHANDLED_OP("stsprp", opcode->op);
}

void mem_ldw(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    fprintf(stream," (r%d + %d), r%d", opcode->r1, opcode->immed, opcode->r2);
    cpu->regs[opcode->r2] = handle_read( cpu, opcode->r1, opcode->immed, stream);
}

void mem_ldwp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    UNHANDLED_OP("ldwp", opcode->op);
}

void mem_lds(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    fprintf(stream," (r%d + %d), r%d", opcode->r1, opcode->immed, opcode->r2);
    cpu->regs[opcode->r2] = handle_read_short( cpu, opcode->r1, opcode->immed, stream);
}

void mem_ldsp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    UNHANDLED_OP("ldsp", opcode->op);
}

void mem_ldb(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    fprintf(stream," (r%d + %d), r%d", opcode->r1, opcode->immed, opcode->r2);
    cpu->regs[opcode->r2] = handle_read_byte( cpu, opcode->r1, opcode->immed, stream);
}

void mem_ldbp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    fprintf(stream," (r%d + %d), r%d", opcode->r1, opcode->immed, opcode->r2);
    cpu->regs[opcode->r2] = handle_read_byte( cpu, opcode->r1, opcode->immed, stream);
    cpu->regs[opcode->r1]++;
}

void mem_ldspr(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {

    fprintf(stream, " (r%d + %d), spr%d ", opcode->r1, opcode->immed, opcode->r2);
    cpu_word_t val = handle_read(cpu, opcode->r1, opcode->immed,stream);
    xtc_set_spr(cpu, opcode->r2, val);
}

void mem_ldsprp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    UNHANDLED_OP("ldsprp", opcode->op);
}

