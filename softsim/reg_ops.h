#ifndef __REG_OPS_H__
#define __REG_OPS_H__
#include <stdio.h>

#include "cpu.h"
#include "opcodes.h"

void reg_addi(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void reg_imm(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void reg_limr(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);
void reg_cmpi(xtc_cpu_t *cpu, const opcode_t *opcode, FILE *stream);


#endif /* __REG_OPS_H__ */