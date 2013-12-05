#include "cflow_ops.h"

void cflow_calli(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    cpu->branchNext = cpu->npc + opcode->immed;
    cpu->br = cpu->npc + 2;
}

void cflow_ret(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    cpu->branchNext = cpu->br;
}

void cflow_bri(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    cpu->branchNext = cpu->npc + opcode->immed;
}

void cflow_brie(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    if (cpu->zero)
        cpu->branchNext = cpu->npc + opcode->immed;
}

void cflow_brine(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    if (!cpu->zero)
        cpu->branchNext = cpu->npc + opcode->immed;
}

void cflow_brilt(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream)
{
    if (!cpu->carry && !cpu->zero)
        cpu->branchNext = cpu->npc + opcode->immed;
}

void cflow_brigt(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream)
{
    // TODO: sign
    if (cpu->carry)
        cpu->branchNext = cpu->npc + opcode->immed;
}

void cflow_briugt(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream)
{
    // TODO: sign
    if (cpu->carry)
        cpu->branchNext = cpu->npc + opcode->immed;
}


