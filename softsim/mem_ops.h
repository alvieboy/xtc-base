#ifndef __MEM_OPS_H__
#define __MEM_OPS_H__
#include <stdio.h>

#include "cpu.h"
#include "opcodes.h"

void mem_stw(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_sts(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_stb(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_stspr(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_stwp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_stsp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_stbp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_stsprp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_ldw(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_ldwp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_lds(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_ldsp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_ldb(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_ldbp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_ldspr(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_ldsprp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);

#endif /* __MEM_OPS_H__ */

