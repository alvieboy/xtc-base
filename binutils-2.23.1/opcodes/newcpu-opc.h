/* newcpu-opc.h -- Newcpu Opcodes
 
   Copyright 2009 Free Software Foundation, Inc.

   This file is part of the GNU opcodes library.

   This library is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   It is distributed in the hope that it will be useful, but WITHOUT
   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
   or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
   License for more details.

   You should have received a copy of the GNU General Public License
   along with this file; see the file COPYING.  If not, write to the
   Free Software Foundation, 51 Franklin Street - Fifth Floor, Boston,
   MA 02110-1301, USA.  */


#ifndef NEWCPU_OPC
#define NEWCPU_OPC

#include "newcpu-opcm.h"


#define INST_TYPE_R1_R2 0
#define INST_TYPE_R1_IMM 1
#define INST_TYPE_IMM 2
#define INST_TYPE_IMM8 3
#define INST_TYPE_IMM8_FLAGS 4
#define INST_TYPE_IMM8_R 5

/* Instructions where the label address is resolved as a PC offset
   (for branch label).  */
#define INST_PC_OFFSET 1 
/* Instructions where the label address is resolved as an absolute 
   value (for data mem or abs address).  */
#define INST_NO_OFFSET 0 

#define OPCODE_MASK_H   0xF000  /* High 4 bits only.  */
#define OPCODE_MASK_BRI   0xF008

#define IMMVAL_MASK_NON_SPECIAL 0x0000
#define IMMVAL_MASK_12 0x0FFF
#define IMMVAL_MASK_8 0x0FF0

#define DELAY_SLOT 1
#define NO_DELAY_SLOT 0

#define MAX_OPCODES 5


struct op_code_struct
{
  char * name;
  short inst_type;            /* Registers and immediate values involved.  */
  short inst_offset_type;     /* Immediate vals offset from PC? (= 1 for branches).  */
  short delay_slots;          /* Info about delay slots needed after this instr. */
  short immval_mask;
  unsigned long bit_sequence; /* All the fixed bits for the op are set and 
				 all the variable bits (reg names, imm vals) 
				 are set to 0.  */ 
  unsigned long opcode_mask;  /* Which bits define the opcode.  */
  enum newcpu_instr instr;
  enum newcpu_instr_type instr_type;
  /* More info about output format here.  */
} opcodes[MAX_OPCODES] = 
{ 
  {"add",   INST_TYPE_R1_R2, INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x0000, OPCODE_MASK_H, add, arithmetic_inst },
  {"and",   INST_TYPE_R1_R2, INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x8400, OPCODE_MASK_H, and, logical_inst },
  {"bri",   INST_TYPE_IMM8,  INST_PC_OFFSET, DELAY_SLOT, IMMVAL_MASK_8, 0x9800, OPCODE_MASK_BRI, bri, branch_inst },
  {"imm",   INST_TYPE_IMM,   INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_12, 0x9800, OPCODE_MASK_H, imm, logical_inst },
  {"", 0, 0, 0, 0, 0, 0, 0, 0},
};

/* Prefix for register names.  */
char register_prefix[] = "r";

/* #defines for valid immediate range.  */
#define MIN_IMM  ((int) 0x80000000)
#define MAX_IMM  ((int) 0x7fffffff)

#define MIN_IMM12 ((int) 0x000)
#define MAX_IMM12 ((int) 0xfff)

#endif /* NEWCPU_OPC */

