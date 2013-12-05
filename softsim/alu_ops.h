#ifndef __ALU_OPS_H__
#define __ALU_OPS_H__
#include <stdio.h>

#include "cpu.h"
#include "opcodes.h"

void alu_add(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void alu_addc(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void alu_sub(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void alu_subb(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void alu_and(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void alu_or(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void alu_copy(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void alu_xor(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void alu_sra(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void alu_srl(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void alu_shl(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void alu_cmp(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);

#endif /* __ALU_OPS_H__ */