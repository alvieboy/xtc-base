/* Disassemble XThunderCore instructions.

   Copyright 2009, 2012 Free Software Foundation, Inc.

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


#include "sysdep.h"
#define STATIC_TABLE
#define DEFINE_TABLE

#include "dis-asm.h"
#include <strings.h>
#include "xtc-opc.h"
#include "xtc-dis.h"

#define get_field_rd(instr)        get_field (instr, RD_MASK, RD_LOW)
#define get_field_r1(instr)        get_field (instr, RA_MASK, RA_LOW)
#define get_field_r2(instr)        get_field (instr, RB_MASK, RB_LOW)
#define get_int_field_imm12(instr)   ((instr & 0xFFF0) >> 4)
#define get_int_field_imm8(instr)   ((instr & 0xFF0) >> 4)
#define get_int_field_r1(instr)    ((instr & RA_MASK) >> RA_LOW)

int
print_insn_xtc (bfd_vma memaddr, struct disassemble_info * info);


static char *
get_field (long instr, long mask, unsigned short low)
{
  char tmpstr[25];

  sprintf (tmpstr, "%s%d", register_prefix, (int)((instr & mask) >> low));
  return (strdup (tmpstr));
}

static char *
get_field_spr (long instr)
{
    char tmpstr[25];
    int spr = (instr & SPR_MASK)>>SPR_LOW;
    switch (spr) {
    case 0:
        sprintf(tmpstr,"y"); break;
    case 1:
        sprintf(tmpstr,"psr"); break;
    case 2:
        sprintf(tmpstr,"spsr"); break;
    case 3:
        sprintf(tmpstr,"tr"); break;
    case 4:
        sprintf(tmpstr,"tpc"); break;
    case 5:
        sprintf(tmpstr,"sr0"); break;
    default:
        sprintf(tmpstr,"<error>"); break;
    }

  return (strdup (tmpstr));
}

static char *
get_field_imm12 (long instr)
{
  char tmpstr[25];

  sprintf (tmpstr, "%d", (short)((instr & IMM_MASK) >> IMM_LOW));
  return (strdup (tmpstr));
}

static char *
get_field_imm8 (long instr)
{
  char tmpstr[25];

  sprintf (tmpstr, "%d", (short)((instr & IMM8_MASK) >> IMM8_LOW));
  return (strdup (tmpstr));
}

static unsigned long
read_insn_xtc (bfd_vma memaddr,
		      struct disassemble_info *info,
		      const struct op_code_struct **opr)
{
  unsigned char       ibytes[4];
  int                 status;
  const struct op_code_struct * op;
  unsigned long inst;

  status = info->read_memory_func (memaddr, ibytes, 2, info);

  if (status != 0)
    {
      info->memory_error_func (status, memaddr, info);
      return 0;
    }

  inst = (ibytes[0] << 8) | ibytes[1];

  /* Check for extended */
  if (inst & 0x8000) {
      /* Load extension */
      status = info->read_memory_func (memaddr+2, &ibytes[2], 2, info);

      if (status != 0)
      {
          info->memory_error_func (status, memaddr, info);
          return 0;
      }
      inst |= (ibytes[2] << 24) | ibytes[3]<<16;
  }

  /* Just a linear search of the table.  */
  for (op = opcodes; op->name != 0; op ++)
    if (op->bit_sequence == (inst & op->opcode_mask))
        break;

  if (op->name==NULL) {
      op = NULL;
  } 

  *opr = op;

  return inst;
}

static const char *getcc(unsigned val)
{
    struct condition_codes_struct *cond;
    for (cond=&condition_codes[0]; cond->name; cond++) {
        if (cond->encoding==val)
            return cond->name;
    }
    return NULL;
}


int
print_insn_xtc (bfd_vma memaddr, struct disassemble_info * info)
{
  fprintf_ftype       print_func = info->fprintf_func;
  void *              stream = info->stream;
  unsigned long       inst;//, prev_inst;
  const struct op_code_struct * op = NULL;//, *pop;
  int                 immval = 0;
  bfd_boolean         immfound = FALSE;
  char                *dreg = NULL;
//  static bfd_vma      prev_insn_addr = -1; /* Init the prev insn addr.  */
//  static int          prev_insn_vma = -1;  /* Init the prev insn vma.  */
//  int                 curr_insn_vma = info->buffer_vma;
  int                 isize = 2;
  int extended=0;

  info->bytes_per_chunk = 2;

  inst = read_insn_xtc (memaddr, info, &op);

  if (inst&0x8000) {
      extended=1;
      isize+=2;
  }

#if 0
  if (prev_insn_vma == curr_insn_vma)
    {
      if (memaddr-(info->bytes_per_chunk) == prev_insn_addr)
        {
          prev_inst = read_insn_xtc (prev_insn_addr, info, &pop);
	  if (pop->instr == imm)
          {
              immval<<=12;
	      immval += get_int_field_imm12 (prev_inst);
              immfound = TRUE;
	    }
	  else
	    {
	      immval = 0;
	      immfound = FALSE;
	    }
	}
    }

  /* Make curr insn as prev insn.  */
  prev_insn_addr = memaddr;
  prev_insn_vma = curr_insn_vma;
#endif

  if ((op==NULL) || (op->name == NULL))
    print_func (stream, ".short 0x%04x", (unsigned int) inst);
  else
    {
        print_func (stream, "%s", op->name);
        if (extended && op->ext!=IS_EXT) {
            print_func(stream,".");
            unsigned ccode = (inst>>24) & 0xf;
            const char *ccname = getcc(ccode);
            if (ccname) {
                print_func(stream,"c%s",ccname);
            }
            /* Print extension */
            switch (inst>>29) {
            case 0x0:                /* Conditional */
                break;
            case 0x1:                /* Dreg, Conditional */
                print_func(stream,"d");
                dreg = get_field(inst, 0xf0000, 16);
                break;
            case 0x2:                /* Imm8, Conditional */
                print_func(stream,"i");
                immval = (inst>>16)&0xff;
                break;
            case 0x3:                /* Imm21, Conditional */
                break;
            default:
                break;
            }
        }
        switch (op->inst_type)
	{
        case INST_TYPE_WSPR:
          print_func (stream, "\t%s, %s", get_field_r1(inst), get_field_spr (inst));
          break;
        case INST_TYPE_RSPR:
          print_func (stream, "\t%s, %s",  get_field_spr (inst), get_field_r1(inst));
          break;
        case INST_TYPE_R1_R2:
        case INST_TYPE_R1_R2_IMM:
            if (dreg) {
                print_func (stream, "\t%s, %s, %s", get_field_r2(inst), get_field_r1 (inst), dreg);
            } else if (immval) {
                print_func (stream, "\t%s, %s, %d", get_field_r2(inst), get_field_r1 (inst), immval);
            } else {
                print_func (stream, "\t%s, %s", get_field_r2(inst), get_field_r1 (inst));
            }
            break;
        case INST_TYPE_MEM_LOAD:
        case INST_TYPE_MEM_LOAD_S:
            if (immval) {
                print_func (stream, "\t(%s + %d), %s", get_field_r1(inst), immval, get_field_r2 (inst));
            } else {
                print_func (stream, "\t(%s), %s", get_field_r1(inst), get_field_r2 (inst));
            }
            break;
        case INST_TYPE_MEM_STORE:
        case INST_TYPE_MEM_STORE_S:
            if (immval) {
                print_func (stream, "\t%s, (%s + %d)", get_field_r2(inst), get_field_r1 (inst),immval);
            } else {
                print_func (stream, "\t%s, (%s)", get_field_r2(inst), get_field_r1 (inst));
            }
            break;
        case INST_TYPE_IMM:
	  print_func (stream, "\t%s", get_field_imm12 (inst));
	  if (info->print_address_func && info->symbol_at_address_func)
	    {
	      if (immfound)
	        immval |= (get_int_field_imm12 (inst) & 0x00000fff);
	      else
		{
	          immval = get_int_field_imm12 (inst);
	          if (immval & 0x800)
		    immval |= 0xFFFFF000;
	        }
	      if (immval > 0 && info->symbol_at_address_func (immval, info))
		{
	          print_func (stream, "\t// ");
	          info->print_address_func (immval, info);
	        }
	    }
	  break;
        case INST_TYPE_IMM8:
        case INST_TYPE_IMM8_FLAGS:
            print_func (stream, "\t%s", get_field_imm8 (inst));
            break;
        case INST_TYPE_IMM8_R:
            print_func (stream, "\t%s, %s", get_field_imm8 (inst), get_field_r1(inst));
            break;
        case INST_TYPE_MEM_IMM8_R:
            print_func (stream, "\t%s + %s", get_field_imm8 (inst), get_field_r1(inst));
            break;
        case INST_TYPE_NOARGS:
            break;
        case INST_TYPE_COP:
            print_func (stream, "\t%lu, %lu, %s", (inst>>9)&0x3, (inst>>7)&0x7, get_field_r1(inst));
            break;
         default:
	  /* If the disassembler lags the instruction set.  */
	  print_func (stream, "\tundecoded operands, inst is 0x%04x", (unsigned int) inst);
	  break;
	}
    }

  if (dreg)
      free(dreg);
  /* Say how many bytes we consumed.  */
  return isize;
}

enum xtc_instr
get_insn_xtc (long inst,
  		     bfd_boolean *isunsignedimm,
  		     //enum xtc_instr_type *insn_type,
  		     short *delay_slots)
{
  const struct op_code_struct * op;
  *isunsignedimm = FALSE;
  *delay_slots=0;

  /* Just a linear search of the table.  */
  for (op = opcodes; op->name != 0; op ++)
    if (op->bit_sequence == (inst & op->opcode_mask))
      break;

  if (op->name == 0) {
      printf("Invalid instruction\n");
      return invalid_inst;
  }
  else
    {
      *isunsignedimm = (op->inst_type == INST_TYPE_IMM);
      //*insn_type = op->instr_type;
      //*delay_slots = op->delay_slots;
      return op->instr;
    }
}

enum xtc_instr
xtc_decode_insn (long insn, int *ra, int *rb, int *immed)
{
  enum xtc_instr op;
  bfd_boolean t1;
  short t3;

  op = get_insn_xtc (insn, &t1, &t3);
  *ra = (insn & RA_MASK) >> RA_LOW;
  *rb = (insn & RB_MASK) >> RB_LOW;
  t3 = (insn & IMM_MASK) >> IMM_LOW;
  *immed = (int) t3;
  return (op);
}

unsigned long
xtc_get_target_address (long inst, bfd_boolean immfound, int immval,
                           long pcval, long r1val,
                           bfd_boolean *targetvalid,
                           bfd_boolean *unconditionalbranch)
{
    const struct op_code_struct * op;
    long targetaddr = 0;

    *unconditionalbranch = FALSE;
    /* Just a linear search of the table.  */
    for (op = opcodes; op->name != 0; op ++)
        if (op->bit_sequence == (inst & op->opcode_mask))
            break;

    printf("xtc_get_target_address\n");
    if (op->name == 0)
    {
        *targetvalid = FALSE;
    }
    else //if (op->instr_type == branch_inst)
    {
        switch (op->inst_type)
        {

        case INST_TYPE_IMM8:
            *unconditionalbranch = TRUE;
            /* Fall through.  */
        case INST_TYPE_IMM8_FLAGS:
            if (immfound)
            {
                targetaddr = (immval << 8) & 0xffffff00;
                targetaddr |= get_int_field_imm8 (inst);
            }
            else
            {
                targetaddr = get_int_field_imm8 (inst);
                if (targetaddr & 0x80)
                    targetaddr |= 0xFFFFFF00;
            }
            if (op->inst_offset_type == INST_PC_OFFSET)
                targetaddr += pcval;
            *targetvalid = TRUE;
            break;
        case INST_TYPE_IMM8_R:
            if (immfound)
            {
                targetaddr = (immval << 8) & 0xffffff00;
                targetaddr |= get_int_field_imm8 (inst);
            }
            else
            {
                targetaddr = get_int_field_imm8 (inst);
                if (targetaddr & 0x80)
                    targetaddr |= 0xFFFFFF00;
            }
            targetaddr += r1val;
            if (op->inst_offset_type == INST_PC_OFFSET)
                targetaddr += pcval;
            *targetvalid = TRUE;
            break;
        default:
            *targetvalid = FALSE;
            break;
        }
    }
    //else
      //  *targetvalid = FALSE;
    return targetaddr;
}
