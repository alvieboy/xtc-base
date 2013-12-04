#ifndef __MEM_OPS_H__
#define __MEM_OPS_H__
#include <stdio.h>

#include "cpu.h"
#include "opcodes.h"

void mem_stwi(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_ldwi(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_ldpw(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_ldwp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_ldmw(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_ldwm(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_lds(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_ldps(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_ldsp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_ldb(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_ldpb(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void mem_ldbp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);


#endif /* __MEM_OPS_H__ */

