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
    subb,
    and,
    or,
    copy,
    cmp,
    xor,
    shl,
    shr,
    srl,
    sra,
    mul,

    not,
    cadd,
    csub,
    sextb,
    sexts,

    bri,

    imm,
    limr,

    stw,
    sts,
    stb,
    stspr,
    stwpostinc,
    stspostinc,
    stbpostinc,
    stsprpostinc,

    ldw,
    lds,
    ldb,
    ldspr,
    ldwpostinc,
    ldspostinc,
    ldbpostinc,
    ldsprpostinc,

#if 0 /* Old instructions not supported any more */
    ldwi,
    ldhi,
    ldbi,
    ldwpreinc,
    ldwpredec,
    ldwpostdec,
    ldhpreinc,
    ldhpostinc,
    ldbpreinc,
#endif

    addi,
    addri,
    cmpi,
    call,
    callr,
    brr,
    lsr,
    ssr,
    jmp,
    jmpe,
    copr,
    copw,
    rspr,
    wspr,

    invalid_inst
};

#define INST_WORD_SIZE 2

#define MIN_REGNUM 0
#define MAX_REGNUM 31

#define REG_Y     16 /* Y  */
#define REG_PSR   17
#define REG_SPSR  18
#define REG_TR    19
#define REG_TPC    20
#define REG_SR0    21

/* Alternate names for gen purpose regs.  */
#define REG_SP  15 /* stack pointer.  */

/* Assembler Register - Used in Delay Slot Optimization.  */
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
