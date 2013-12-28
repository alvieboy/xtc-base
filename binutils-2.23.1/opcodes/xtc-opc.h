/* xtc-opc.h -- XThunderCore Opcodes
 
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


#ifndef XTC_OPC
#define XTC_OPC

#include "xtc-opcm.h"


#define INST_TYPE_R1_R2 0
#define INST_TYPE_IMM 2
#define INST_TYPE_IMM8 3
#define INST_TYPE_IMM8_FLAGS 4
#define INST_TYPE_IMM8_R 5
#define INST_TYPE_MEM 6
#define INST_TYPE_NOARGS 7
#define INST_TYPE_MEM_INDIRECT 8
#define INST_TYPE_SR 9
#define INST_TYPE_MEM_IMM8_R 10
#define INST_TYPE_R 11
#define INST_TYPE_MEM_S 12
#define INST_TYPE_R1_R2_IMM 13


/* Instructions where the label address is resolved as a PC offset
   (for branch label).  */
#define INST_PC_OFFSET 1 
/* Instructions where the label address is resolved as an absolute 
   value (for data mem or abs address).  */
#define INST_NO_OFFSET 0 

#define OPCODE_MASK_H   0xF000  /* High 4 bits only.  */
#define OPCODE_MASK_EXT 0xFF00  /* High 8 bits only.  */
#define OPCODE_MASK_REGONLY 0xFFF0  /* High 8 bits only.  */

#define OPCODE_MASK_MEM OPCODE_MASK_EXT
#define OPCODE_MASK_ARITH  0xFF00
#define OPCODE_MASK_BRI    0xF000
#define OPCODE_MASK_BRIF   0xF00F

#define IMMVAL_MASK_NON_SPECIAL 0x0000
#define IMMVAL_MASK_12 0x0FFF
#define IMMVAL_MASK_8 0x0FF0

#define DELAY_SLOT 1
#define NO_DELAY_SLOT 0

#define MAX_OPCODES 70


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
  enum xtc_instr instr;
  enum xtc_instr_type instr_type;
  /* More info about output format here.  */
} opcodes[MAX_OPCODES] = 
{ 
    {"add",   INST_TYPE_R1_R2, INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x1000, OPCODE_MASK_ARITH, add, arithmetic_inst },
    {"addc",  INST_TYPE_R1_R2, INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x1100, OPCODE_MASK_ARITH, addc,arithmetic_inst },
    {"sub",   INST_TYPE_R1_R2, INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x1200, OPCODE_MASK_ARITH, sub, arithmetic_inst },
    {"subb",  INST_TYPE_R1_R2, INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x1300, OPCODE_MASK_ARITH, subb, arithmetic_inst },

    {"and",   INST_TYPE_R1_R2, INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x1400, OPCODE_MASK_ARITH, and, logical_inst },
    {"or",    INST_TYPE_R1_R2, INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x1500, OPCODE_MASK_ARITH, or,  logical_inst },
    {"cmp",   INST_TYPE_R1_R2, INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x1600, OPCODE_MASK_ARITH, cmp,logical_inst },
    {"xor",   INST_TYPE_R1_R2, INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x1700, OPCODE_MASK_ARITH, xor,  logical_inst },

    {"shl",   INST_TYPE_R1_R2, INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x1800, OPCODE_MASK_ARITH, shl,logical_inst },
    {"srl",   INST_TYPE_R1_R2, INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x1900, OPCODE_MASK_ARITH, srl,logical_inst },
    {"sra",   INST_TYPE_R1_R2, INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x1A00, OPCODE_MASK_ARITH, sra,logical_inst },
    {"mul",   INST_TYPE_R1_R2, INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x1B00, OPCODE_MASK_ARITH, mul, arithmetic_inst },

    /* Single-reg ops */
    {"not",   INST_TYPE_R,     INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x0010, OPCODE_MASK_REGONLY, not,logical_inst },
    {"sextb",   INST_TYPE_R,     INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x0020, OPCODE_MASK_REGONLY, sextb,logical_inst },
    {"sexts",   INST_TYPE_R,     INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x0030, OPCODE_MASK_REGONLY, sexts,logical_inst },

    {"limr",  INST_TYPE_IMM8_R, INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0xE000, OPCODE_MASK_H, limr, immediate_inst },

    {"stw",    INST_TYPE_MEM,    INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x2000, OPCODE_MASK_MEM, stw, memory_store_inst },
    {"sts",    INST_TYPE_MEM,    INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x2100, OPCODE_MASK_MEM, sts, memory_store_inst },
    {"stb",    INST_TYPE_MEM,    INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x2200, OPCODE_MASK_MEM, stb, memory_store_inst },
    {"stspr",  INST_TYPE_MEM_S,  INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x2300, OPCODE_MASK_MEM, stspr, memory_store_inst },
    {"stw+",   INST_TYPE_MEM,    INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x2400, OPCODE_MASK_MEM, stwpostinc, memory_store_inst },
    {"sts+",   INST_TYPE_MEM,    INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x2500, OPCODE_MASK_MEM, stspostinc, memory_store_inst },
    {"stb+",   INST_TYPE_MEM,    INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x2600, OPCODE_MASK_MEM, stbpostinc, memory_store_inst },
    {"stspr+", INST_TYPE_MEM_S,  INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x2700, OPCODE_MASK_MEM, stsprpostinc, memory_store_inst },

    {"ldw",    INST_TYPE_MEM,    INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x4000, OPCODE_MASK_MEM, ldw, memory_load_inst },
    {"lds",    INST_TYPE_MEM,    INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x4100, OPCODE_MASK_MEM, lds, memory_load_inst },
    {"ldb",    INST_TYPE_MEM,    INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x4200, OPCODE_MASK_MEM, ldb, memory_load_inst },
    {"ldspr",  INST_TYPE_MEM_S,  INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x4300, OPCODE_MASK_MEM, ldspr, memory_load_inst },
    {"ldw+",   INST_TYPE_MEM,    INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x4400, OPCODE_MASK_MEM, ldwpostinc, memory_load_inst },
    {"lds+",   INST_TYPE_MEM,    INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x4500, OPCODE_MASK_MEM, ldspostinc, memory_load_inst },
    {"ldb+",   INST_TYPE_MEM,    INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x4500, OPCODE_MASK_MEM, ldbpostinc, memory_load_inst },
    {"ldspr+", INST_TYPE_MEM_S,  INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x4700, OPCODE_MASK_MEM, ldsprpostinc, memory_load_inst },

    // TODO: BRI will be IMM8_R, not IMM0
    {"bri",   INST_TYPE_IMM8,  INST_PC_OFFSET, DELAY_SLOT, IMMVAL_MASK_8, 0x9000, OPCODE_MASK_H, bri, branch_inst },

    {"brieq", INST_TYPE_IMM8,  INST_PC_OFFSET, DELAY_SLOT, IMMVAL_MASK_8, 0xA008, OPCODE_MASK_BRIF, brie, branch_inst },
    {"brine", INST_TYPE_IMM8,  INST_PC_OFFSET, DELAY_SLOT, IMMVAL_MASK_8, 0xA009, OPCODE_MASK_BRIF, brine, branch_inst },
    {"brigt", INST_TYPE_IMM8,  INST_PC_OFFSET, DELAY_SLOT, IMMVAL_MASK_8, 0xA00A, OPCODE_MASK_BRIF, brig, branch_inst },
    {"brige", INST_TYPE_IMM8,  INST_PC_OFFSET, DELAY_SLOT, IMMVAL_MASK_8, 0xA00B, OPCODE_MASK_BRIF, brige, branch_inst },
    {"brilt", INST_TYPE_IMM8,  INST_PC_OFFSET, DELAY_SLOT, IMMVAL_MASK_8, 0xA00C, OPCODE_MASK_BRIF, bril, branch_inst },
    {"brile", INST_TYPE_IMM8,  INST_PC_OFFSET, DELAY_SLOT, IMMVAL_MASK_8, 0xA00D, OPCODE_MASK_BRIF, brile, branch_inst },
    {"briugt", INST_TYPE_IMM8,  INST_PC_OFFSET, DELAY_SLOT, IMMVAL_MASK_8, 0xA00E, OPCODE_MASK_BRIF, briugt, branch_inst },
    {"briuge", INST_TYPE_IMM8,  INST_PC_OFFSET, DELAY_SLOT, IMMVAL_MASK_8, 0xA00F, OPCODE_MASK_BRIF, briuge, branch_inst },
    {"briult", INST_TYPE_IMM8,  INST_PC_OFFSET, DELAY_SLOT, IMMVAL_MASK_8, 0xA001, OPCODE_MASK_BRIF, briult, branch_inst },
    {"briule", INST_TYPE_IMM8,  INST_PC_OFFSET, DELAY_SLOT, IMMVAL_MASK_8, 0xA002, OPCODE_MASK_BRIF, briule, branch_inst },

    // TODO: this will be renamed to BR.
    {"brr", INST_TYPE_MEM_IMM8_R,  INST_NO_OFFSET, DELAY_SLOT, IMMVAL_MASK_8, 0xB000, OPCODE_MASK_H, brr, branch_inst },
    {"calla", INST_TYPE_MEM_IMM8_R,  INST_NO_OFFSET, DELAY_SLOT, IMMVAL_MASK_8, 0xC000, OPCODE_MASK_H, call, branch_inst },

    {"call", INST_TYPE_IMM8_R,  INST_PC_OFFSET, DELAY_SLOT, IMMVAL_MASK_8, 0xD000, OPCODE_MASK_H, callr, branch_inst },

    {"lsr", INST_TYPE_SR,  INST_NO_OFFSET, DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x0100, OPCODE_MASK_EXT, lsr, arithmetic_inst },
    {"ssr", INST_TYPE_SR,  INST_NO_OFFSET, DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x0200, OPCODE_MASK_EXT, lsr, arithmetic_inst },


    {"imm",   INST_TYPE_IMM,   INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_12, 0x8000, OPCODE_MASK_H, imm, immediate_inst },

    {"addi",  INST_TYPE_IMM8_R, INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_8, 0x6000, OPCODE_MASK_H, addi, immediate_inst },
    {"addri",  INST_TYPE_R1_R2_IMM, INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_8, 0x5000, OPCODE_MASK_H, addri, immediate_inst },
    {"cmpi",  INST_TYPE_IMM8_R, INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_8, 0x7000, OPCODE_MASK_H, cmpi, immediate_inst },

    {"ret",   INST_TYPE_NOARGS,   INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0xF000, OPCODE_MASK_H, ret, branch_inst },

    {"nop",   INST_TYPE_NOARGS,   INST_NO_OFFSET, NO_DELAY_SLOT, IMMVAL_MASK_NON_SPECIAL, 0x0000, OPCODE_MASK_EXT, nop, logical_inst },
    {"", 0, 0, 0, 0, 0, 0, 0, 0},
};

/* Prefix for register names.  */
char register_prefix[] = "r";

/* #defines for valid immediate range.  */
#define MIN_IMM  ((int) 0x80000000)
#define MAX_IMM  ((int) 0x7fffffff)

#define MIN_IMM12 ((int) 0x000)
#define MAX_IMM12 ((int) 0xfff)

#endif /* XTC_OPC */

