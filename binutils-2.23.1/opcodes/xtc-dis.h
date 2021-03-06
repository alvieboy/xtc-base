/* Disassemble xtc instructions.

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

#ifndef XTC_DIS_H
#define XTC_DIS_H 1

extern enum xtc_instr xtc_decode_insn (long, int *, int *, int *);
extern unsigned long xtc_get_target_address (long, bfd_boolean, int,
                                             long, long, bfd_boolean *,
                                             bfd_boolean *);

extern enum xtc_instr get_insn_xtc (long, bfd_boolean *, 
                                    //enum xtc_instr_type *,
                                    short *);

#endif /* xtc-dis.h */
