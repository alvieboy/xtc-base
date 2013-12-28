#include "cflow_ops.h"

void cflow_calli(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    cpu->branchNext = cpu->npc + opcode->immed;
    fprintf(stream, " %d (0x%08x)", opcode->immed, cpu->branchNext);
    cpu->spr.r.br = cpu->npc + 2;
}

void cflow_ret(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    fprintf(stream, " (br = 0x%08x)", cpu->spr.r.br);
    cpu->branchNext = cpu->spr.r.br;
}

void cflow_bri(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    cpu->branchNext = cpu->npc + opcode->immed;
    fprintf(stream, " %d (0x%08x)", opcode->immed, cpu->branchNext);
}

void cflow_brie(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    if (cpu->zero) {
        cpu->branchNext = cpu->npc + opcode->immed;
        fprintf(stream, " %d (0x%08x)", opcode->immed, cpu->branchNext);
    } else {
        fprintf(stream, " %d (not taken)", opcode->immed);
    }
}

void cflow_brine(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream) {
    if (!cpu->zero) {
        cpu->branchNext = cpu->npc + opcode->immed;
        fprintf(stream, " %d (0x%08x)", opcode->immed, cpu->branchNext);
    } else {
        fprintf(stream, " %d (not taken)", opcode->immed);
    }
}

void cflow_brilt(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream)
{
    if (cpu->sign) {
        cpu->branchNext = cpu->npc + opcode->immed;
        fprintf(stream, " %d (0x%08x)", opcode->immed, cpu->branchNext);
    } else {
        fprintf(stream, " %d (not taken)", opcode->immed);
    }

}

void cflow_brile(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream)
{
    if (cpu->sign || cpu->zero) {
        cpu->branchNext = cpu->npc + opcode->immed;
        fprintf(stream, " %d (0x%08x)", opcode->immed, cpu->branchNext);
    } else {
        fprintf(stream, " %d (not taken)", opcode->immed);
    }

}

void cflow_brigt(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream)
{
    // TODO: sign
    if (!cpu->sign && !cpu->zero) {
        cpu->branchNext = cpu->npc + opcode->immed;
        fprintf(stream, " %d (0x%08x)", opcode->immed, cpu->branchNext);
    } else {
        fprintf(stream, " %d (not taken)", opcode->immed);
    }
}

void cflow_brige(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream)
{
    if (!cpu->sign) {
        cpu->branchNext = cpu->npc + opcode->immed;
        fprintf(stream, " %d (0x%08x)", opcode->immed, cpu->branchNext);
    } else {
        fprintf(stream, " %d (not taken)", opcode->immed);
    }

}

void cflow_briugt(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream)
{
    // TODO: sign
    if (!cpu->carry) {
        cpu->branchNext = cpu->npc + opcode->immed;
        fprintf(stream, " %d (0x%08x)", opcode->immed, cpu->branchNext);
    } else {
        fprintf(stream, " %d (not taken)", opcode->immed);
    }
}

void cflow_briuge(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream)
{
    // TODO: sign
    if (!cpu->carry || cpu->zero) {
        cpu->branchNext = cpu->npc + opcode->immed;
        fprintf(stream, " %d (0x%08x)", opcode->immed, cpu->branchNext);
    } else {
        fprintf(stream, " %d (not taken)", opcode->immed);
    }
}

void cflow_briult(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream)
{
    // TODO: sign
    if (cpu->carry) {
        cpu->branchNext = cpu->npc + opcode->immed;
        fprintf(stream, " %d (0x%08x)", opcode->immed, cpu->branchNext);
    } else {
        fprintf(stream, " %d (not taken)", opcode->immed);
    }
}
void cflow_briule(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream)
{
    // TODO: sign
    if (cpu->carry || cpu->zero) {
        cpu->branchNext = cpu->npc + opcode->immed;
        fprintf(stream, " %d (0x%08x)", opcode->immed, cpu->branchNext);
    } else {
        fprintf(stream, " %d (not taken)", opcode->immed);
    }
}


