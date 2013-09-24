/* newcpu-opcm.h -- Header used in newcpu-opc.h

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
 

#ifndef NEWCPU_OPCM
#define NEWCPU_OPCM

enum newcpu_instr
{
    nop,
    add,
    addc,
    sub,
    and,
    or,
    not,
    bri,
    brie,
    brine,
    brig,
    brige,
    bril,
    brile,
    imm,
    limr,
    stw,
    stwpreinc,
    stwpostinc,
    stwpredec,
    stwpostdec,
    sth,
    sthpreinc,
    sthpostinc,
    stb,
    stbpreinc,
    stbpostinc,
    stwi,
    sthi,
    stbi,

    ldw,
    ldwpreinc,
    ldwpostinc,
    ldwpredec,
    ldwpostdec,
    ldh,
    ldhpreinc,
    ldhpostinc,
    ldb,
    ldbpreinc,
    ldbpostinc,
    ldwi,
    ldhi,
    ldbi,

    addi,
    call,
    callr,
    brr,
    lsr,
    ssr,
    ret,

    invalid_inst
};

enum newcpu_instr_type
{
  arithmetic_inst, logical_inst, mult_inst, div_inst, branch_inst,
  return_inst, immediate_inst, special_inst, memory_load_inst,
  memory_store_inst, barrel_shift_inst, anyware_inst
};

#define INST_WORD_SIZE 2

/* Gen purpose regs go from 0 to 31.  */
/* Mask is reg num - max_reg_num, ie reg_num - 32 in this case.  */

#define REG_PC_MASK  0x8000
#define REG_MSR_MASK 0x8001
#define REG_EAR_MASK 0x8003
#define REG_ESR_MASK 0x8005
#define REG_FSR_MASK 0x8007
#define REG_BTR_MASK 0x800b
#define REG_EDR_MASK 0x800d
#define REG_PVR_MASK 0xa000

#define REG_PID_MASK   0x9000
#define REG_ZPR_MASK   0x9001
#define REG_TLBX_MASK  0x9002
#define REG_TLBLO_MASK 0x9003
#define REG_TLBHI_MASK 0x9004
#define REG_TLBSX_MASK 0x9005

#define MIN_REGNUM 0
#define MAX_REGNUM 31

#define REG_PC  32 /* PC.  */
#define REG_Y  33 /* Y  */
#define REG_BR  34 /* BR  */

/* Alternate names for gen purpose regs.  */
#define REG_SP  1 /* stack pointer.  */

/* Assembler Register - Used in Delay Slot Optimization.  */
#define REG_AS    18
#define REG_ZERO  0
 
#define RA_LOW  0 /* Low bit for RA.  */
#define RB_LOW  4 /* Low bit for RB.  */
#define IMM_LOW  0 /* Low bit for immediate.  */
#define IMM8_LOW  4 /* Low bit for 8-bit immediate.  */
#define RA_MASK 0x000F
#define RB_MASK 0x00F0

#define SPR_LOW 4
#define SPR_MASK 0x0070

#define IMM_MASK 0x0FFF
#define IMM8_MASK 0x0FF0

#endif /* NEWCPU-OPCM */
