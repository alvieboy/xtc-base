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
#define INST_TYPE_MEM_LOAD 6
#define INST_TYPE_NOARGS 7
#define INST_TYPE_MEM_INDIRECT 8
#define INST_TYPE_SR 9
#define INST_TYPE_MEM_IMM8_R 10
#define INST_TYPE_R 11
#define INST_TYPE_MEM_LOAD_S 12
#define INST_TYPE_R1_R2_IMM 13
#define INST_TYPE_MEM_STORE 14
#define INST_TYPE_MEM_STORE_S 15
#define INST_TYPE_COP 16

/* Instructions where the label address is resolved as a PC offset
   (for branch label).  */
#define INST_PC_OFFSET 1 
/* Instructions where the label address is resolved as an absolute 
   value (for data mem or abs address).  */
#define INST_NO_OFFSET 0 

#define OPCODE_MASK_H       0x7000  /* High 4 bits only.  */
#define OPCODE_MASK_EXT     0x7F00  /* High 7 bits only.  */
#define OPCODE_MASK_REGONLY 0x7FF0  /* High 11 bits only.  */

#define OPCODE_MASK_MEM     OPCODE_MASK_EXT
#define OPCODE_MASK_ARITH   OPCODE_MASK_EXT
#define OPCODE_MASK_BRI     0x7000
#define OPCODE_MASK_COP     0x7C00

#define OPCODE_MASK_IMM    0x60008000

#define IMMVAL_MASK_NON_SPECIAL 0x0000
#define IMMVAL_MASK_12 0x0FFF
#define IMMVAL_MASK_8 0x0FF0

#define DELAY_SLOT 1
#define NO_DELAY_SLOT 0

typedef enum {
    NO_EXT,  /* Cannot be extended */
    IS_EXT,  /* Is extended */
    CAN_EXT_DREG,  /* Can be extended with DREG */
    CAN_EXT_IMMED,  /* Can be extended with IMMED */
    CAN_EXT_ALL /* Can be extended with all */
} xtc_ext_ability_t;

typedef enum {
    NO_IMM,
    IMM8,
    IMM_CHANGES_MEANING /* This instruction, when appended with IMM, has a diferent meaning */
} xtc_imm_type_t;

const struct op_code_struct
{
    const char *name;
    xtc_ext_ability_t ext;
    xtc_imm_type_t imm;
    short inst_type;            /* Registers and immediate values involved.  */
    unsigned long bit_sequence; /* All the fixed bits for the op are set and
    all the variable bits (reg names, imm vals)
				 are set to 0.  */ 
    unsigned long opcode_mask;  /* Which bits define the opcode.  */
    int inst_offset_type;
    enum xtc_instr instr;

} opcodes[] =
{
    {"imm",   IS_EXT,      IMM8,   INST_TYPE_IMM, 0x60008000, OPCODE_MASK_IMM, INST_NO_OFFSET, imm },

    {"add",   CAN_EXT_ALL, NO_IMM, INST_TYPE_R1_R2, 0x0000, OPCODE_MASK_ARITH, INST_NO_OFFSET, add  },
    {"addc",  CAN_EXT_ALL, NO_IMM, INST_TYPE_R1_R2, 0x0100, OPCODE_MASK_ARITH, INST_NO_OFFSET, addc },
    {"sub",   CAN_EXT_ALL, NO_IMM, INST_TYPE_R1_R2, 0x0200, OPCODE_MASK_ARITH, INST_NO_OFFSET, sub  },
    {"subb",  CAN_EXT_ALL, NO_IMM, INST_TYPE_R1_R2, 0x0300, OPCODE_MASK_ARITH, INST_NO_OFFSET, subb },

    {"and",   CAN_EXT_ALL, NO_IMM, INST_TYPE_R1_R2, 0x0400, OPCODE_MASK_ARITH, INST_NO_OFFSET, and  },
    {"or",    CAN_EXT_ALL, NO_IMM, INST_TYPE_R1_R2, 0x0500, OPCODE_MASK_ARITH, INST_NO_OFFSET, or  },
    {"xor",   CAN_EXT_ALL, NO_IMM, INST_TYPE_R1_R2, 0x0600, OPCODE_MASK_ARITH, INST_NO_OFFSET, cmp  },
    {"cmp",   CAN_EXT_ALL, NO_IMM, INST_TYPE_R1_R2, 0x0700, OPCODE_MASK_ARITH, INST_NO_OFFSET, xor  },

    {"shl",   CAN_EXT_ALL, NO_IMM, INST_TYPE_R1_R2, 0x0800, OPCODE_MASK_ARITH, INST_NO_OFFSET, shl  },
    {"srl",   CAN_EXT_ALL, NO_IMM, INST_TYPE_R1_R2, 0x0900, OPCODE_MASK_ARITH, INST_NO_OFFSET, srl  },
    {"sra",   CAN_EXT_ALL, NO_IMM, INST_TYPE_R1_R2, 0x0A00, OPCODE_MASK_ARITH, INST_NO_OFFSET, sra  },
    {"mul",   CAN_EXT_ALL, NO_IMM, INST_TYPE_R1_R2, 0x0B00, OPCODE_MASK_ARITH, INST_NO_OFFSET, mul  },
    {"addr",  CAN_EXT_ALL, NO_IMM, INST_TYPE_R1_R2, 0x0C00, OPCODE_MASK_ARITH, INST_NO_OFFSET, addri },
    {"not",   CAN_EXT_ALL, NO_IMM, INST_TYPE_R1_R2, 0x0D00, OPCODE_MASK_ARITH, INST_NO_OFFSET, not },
    {"cadd",  CAN_EXT_ALL, NO_IMM, INST_TYPE_R1_R2, 0x0E00, OPCODE_MASK_ARITH, INST_NO_OFFSET, cadd  },
    {"csub",  CAN_EXT_ALL, NO_IMM, INST_TYPE_R1_R2, 0x0F00, OPCODE_MASK_ARITH, INST_NO_OFFSET, csub },

    
    {"stw",    CAN_EXT_IMMED, NO_IMM, INST_TYPE_MEM_STORE,    0x1000, OPCODE_MASK_MEM, INST_NO_OFFSET, stw },
    {"sts",    CAN_EXT_IMMED, NO_IMM, INST_TYPE_MEM_STORE,    0x1100, OPCODE_MASK_MEM, INST_NO_OFFSET, sts },
    {"stb",    CAN_EXT_IMMED, NO_IMM, INST_TYPE_MEM_STORE,    0x1200, OPCODE_MASK_MEM, INST_NO_OFFSET, stb },
    {"stspr",  CAN_EXT_IMMED, NO_IMM, INST_TYPE_MEM_STORE_S,  0x1300, OPCODE_MASK_MEM, INST_NO_OFFSET, stspr },
    {"stw+",   CAN_EXT_IMMED, NO_IMM, INST_TYPE_MEM_STORE,    0x1400, OPCODE_MASK_MEM, INST_NO_OFFSET, stwpostinc },
    {"sts+",   CAN_EXT_IMMED, NO_IMM, INST_TYPE_MEM_STORE,    0x1500, OPCODE_MASK_MEM, INST_NO_OFFSET, stspostinc },
    {"stb+",   CAN_EXT_IMMED, NO_IMM, INST_TYPE_MEM_STORE,    0x1600, OPCODE_MASK_MEM, INST_NO_OFFSET, stbpostinc },
    {"stspr+", CAN_EXT_IMMED, NO_IMM, INST_TYPE_MEM_STORE_S,  0x1700, OPCODE_MASK_MEM, INST_NO_OFFSET, stsprpostinc },

    {"ldw",    CAN_EXT_IMMED, NO_IMM, INST_TYPE_MEM_LOAD,    0x1800, OPCODE_MASK_MEM, INST_NO_OFFSET, ldw },
    {"lds",    CAN_EXT_IMMED, NO_IMM, INST_TYPE_MEM_LOAD,    0x1900, OPCODE_MASK_MEM, INST_NO_OFFSET, lds },
    {"ldb",    CAN_EXT_IMMED, NO_IMM, INST_TYPE_MEM_LOAD,    0x1A00, OPCODE_MASK_MEM, INST_NO_OFFSET, ldb },
    {"ldspr",  CAN_EXT_IMMED, NO_IMM, INST_TYPE_MEM_LOAD_S,  0x1B00, OPCODE_MASK_MEM, INST_NO_OFFSET, ldspr },
    {"ldw+",   CAN_EXT_IMMED, NO_IMM, INST_TYPE_MEM_LOAD,    0x1C00, OPCODE_MASK_MEM, INST_NO_OFFSET, ldwpostinc },
    {"lds+",   CAN_EXT_IMMED, NO_IMM, INST_TYPE_MEM_LOAD,    0x1D00, OPCODE_MASK_MEM, INST_NO_OFFSET, ldspostinc },
    {"ldb+",   CAN_EXT_IMMED, NO_IMM, INST_TYPE_MEM_LOAD,    0x1E00, OPCODE_MASK_MEM, INST_NO_OFFSET, ldbpostinc },
    {"ldspr+", CAN_EXT_IMMED, NO_IMM, INST_TYPE_MEM_LOAD_S,  0x1F00, OPCODE_MASK_MEM, INST_NO_OFFSET, ldsprpostinc },

    {"copr",   NO_EXT,        NO_IMM, INST_TYPE_COP,         0x2000, OPCODE_MASK_COP, INST_NO_OFFSET, copr },
    {"copw",   NO_EXT,        NO_IMM, INST_TYPE_COP,         0x2400, OPCODE_MASK_COP, INST_NO_OFFSET, copw },

    {"br",     CAN_EXT_IMMED, IMM8, INST_TYPE_IMM8_R, 0x4000, OPCODE_MASK_H, INST_PC_OFFSET, bri },
    {"addi",   CAN_EXT_ALL,   IMM8, INST_TYPE_IMM8_R, 0x5000, OPCODE_MASK_H, INST_NO_OFFSET, addi },
    {"cmpi",   CAN_EXT_IMMED, IMM8, INST_TYPE_IMM8_R, 0x6000, OPCODE_MASK_H, INST_NO_OFFSET, cmpi },
    {"limr",   CAN_EXT_IMMED, IMM8, INST_TYPE_IMM8_R, 0x7000, OPCODE_MASK_H, INST_NO_OFFSET, limr },

    {"jmp",    NO_EXT,       NO_IMM, INST_TYPE_R1_R2, 0x3000, OPCODE_MASK_ARITH, INST_NO_OFFSET, jmp },
    {"jmpe",   NO_EXT,       NO_IMM, INST_TYPE_R1_R2, 0x3400, OPCODE_MASK_ARITH, INST_NO_OFFSET, jmpe },
    {"sextb", CAN_EXT_ALL, NO_IMM, INST_TYPE_R1_R2, 0x3800, OPCODE_MASK_ARITH, INST_NO_OFFSET, sextb },
    {"sexts", CAN_EXT_ALL, NO_IMM, INST_TYPE_R1_R2, 0x3A00, OPCODE_MASK_ARITH, INST_NO_OFFSET, sexts },


    {"nop",    NO_EXT,       NO_IMM, INST_TYPE_NOARGS, 0x3810, 0x7fff, INST_NO_OFFSET, nop },
    { NULL, 0, 0, 0, 0, 0, 0, 0},
};

/* Prefix for register names.  */
char register_prefix[] = "r";

/* Condition codes */

struct condition_codes_struct {
    const char *name;
    unsigned long encoding;
} condition_codes[] = {
    { "ne", 1 },
    { "eq",  2 },
    { "gt",  3 },
    { "ge",  4 },
    { "lt",  5 },
    { "le",  6 },
    { "ugt",  7 },
    { "uge",  8 },
    { "ult",  9 },
    { "ule",  10 },
    { "s",  11 },
    { "ns",  12 },
    { NULL, 0 }
};

/* #defines for valid immediate range.  */
#define MIN_IMM  ((int) 0x80000000)
#define MAX_IMM  ((int) 0x7fffffff)

#define MIN_IMM12 ((int) 0x000)
#define MAX_IMM12 ((int) 0xfff)

#endif /* XTC_OPC */

