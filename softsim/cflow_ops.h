#ifndef __CLFLOW_OPS_H__
#define __CLFLOW_OPS_H__
#include <stdio.h>

#include "cpu.h"
#include "opcodes.h"

void cflow_calli(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void cflow_ret(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void cflow_bri(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void cflow_brie(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void cflow_brine(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void cflow_brilt(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void cflow_brigt(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void cflow_briugt(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);

#endif /* __CLFLOW_OPS_H__ */

