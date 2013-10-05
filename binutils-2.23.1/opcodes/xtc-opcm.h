/* xtc-opcm.h -- Header used in xtc-opc.h

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
 

#ifndef XTC_OPCM
#define XTC_OPCM

enum xtc_instr
{
    nop,
    add,
    addc,
    sub,
    and,
    or,
    copy,
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
    cmpi,
    call,
    callr,
    brr,
    lsr,
    ssr,
    ret,

    invalid_inst
};

enum xtc_instr_type
{
  arithmetic_inst, logical_inst, mult_inst, div_inst, branch_inst,
  return_inst, immediate_inst, special_inst, memory_load_inst,
  memory_store_inst, barrel_shift_inst, anyware_inst
};

#define INST_WORD_SIZE 2

#define MIN_REGNUM 0
#define MAX_REGNUM 31

#define REG_PC  32 /* PC.  */
#define REG_Y  33 /* Y  */
#define REG_BR  34 /* BR  */

/* Alternate names for gen purpose regs.  */
#define REG_SP  15 /* stack pointer.  */

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

#endif /* XTC-OPCM */
