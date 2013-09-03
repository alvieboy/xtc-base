/* newcpu support for BFD.
 
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

/* This file holds definitions specific to the NEWCPU ELF ABI.  */

#ifndef _ELF_NEWCPU_H
#define _ELF_NEWCPU_H

#include "elf/reloc-macros.h"

/* Relocations.  */
START_RELOC_NUMBERS (elf_newcpu_reloc_type)
  RELOC_NUMBER (R_NEWCPU_NONE, 0)
  RELOC_NUMBER (R_NEWCPU_32, 1)
  RELOC_NUMBER (R_NEWCPU_32_PCREL, 2)
END_RELOC_NUMBERS (R_NEWCPU_max)

#endif /* _ELF_NEWCPU_H */
