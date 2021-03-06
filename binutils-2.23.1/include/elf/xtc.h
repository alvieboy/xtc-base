/* xtc support for BFD.
 
   Copyright 2009, 2010 Free Software Foundation, Inc.

   This file is part of BFD, the Binary File Descriptor library.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street - Fifth Floor, Boston, MA 
   02110-1301, USA.  */

/* This file holds definitions specific to the XTC ELF ABI.  */

#ifndef _ELF_XTC_H
#define _ELF_XTC_H

#include "elf/reloc-macros.h"

/* Relocations.  */
START_RELOC_NUMBERS (elf_xtc_reloc_type)
    RELOC_NUMBER (R_XTC_NONE, 0)
    RELOC_NUMBER (R_XTC_32, 1)             /* 32-bit normal reloc, memory */
    RELOC_NUMBER (R_XTC_32_PCREL, 2)       /* 32-bit normal reloc, PCREL */

    RELOC_NUMBER (R_XTC_32_I8, 3)        /* 8-bit IMM reloc */
    RELOC_NUMBER (R_XTC_32_E8, 4)        /* 8-bit IMM reloc */
    RELOC_NUMBER (R_XTC_32_E8_I8, 5)     /* 16-bit IMM reloc */
    RELOC_NUMBER (R_XTC_32_E24, 6)       /* 24-bit IMM reloc */
    RELOC_NUMBER (R_XTC_32_E24_I8, 7)    /* 32-bit IMM reloc */
    RELOC_NUMBER (R_XTC_32_E24_E8, 8)    /* 32-bit IMM reloc */

    RELOC_NUMBER (R_XTC_32_I8_R, 9)        /* 8-bit IMM reloc */
    RELOC_NUMBER (R_XTC_32_E8_R, 10)        /* 8-bit IMM reloc */
    RELOC_NUMBER (R_XTC_32_E8_I8_R, 11)     /* 16-bit IMM reloc */
    RELOC_NUMBER (R_XTC_32_E24_R, 12)       /* 24-bit IMM reloc */
    RELOC_NUMBER (R_XTC_32_E24_I8_R, 13)    /* 32-bit IMM reloc */
    RELOC_NUMBER (R_XTC_32_E24_E8_R, 14)    /* 32-bit IMM reloc */

    RELOC_NUMBER (R_XTC_32_E8_NR, 15)        /* 8-bit IMM reloc */
    RELOC_NUMBER (R_XTC_32_E24_E8_NR,16)    /* 32-bit IMM reloc */

    RELOC_NUMBER (R_XTC_32_E8_NR_R, 17)        /* 8-bit IMM reloc */
    RELOC_NUMBER (R_XTC_32_E24_E8_NR_R, 18)    /* 32-bit IMM reloc */

END_RELOC_NUMBERS (R_XTC_max)

#endif /* _ELF_XTC_H */
