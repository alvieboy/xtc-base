#include "as.h"
#include <stdio.h>
#include "bfd.h"
#include "subsegs.h"
#define DEFINE_TABLE
#include "../opcodes/xtc-opc.h"
#include "../opcodes/xtc-opcm.h"
#include "safe-ctype.h"
#include <string.h>
#include <dwarf2dbg.h>
#include "aout/stab_gnu.h"

#ifndef streq
#define streq(a,b) (strcmp (a, b) == 0)
#endif

/* Several places in this file insert raw instructions into the
   object. They should generate the instruction
   and then use these four macros to crack the instruction value into
   the appropriate byte values.  */
#define	INST_BYTE0(x)  (((x) >> 8) & 0xFF)
#define	INST_BYTE1(x)  (((x) >> 0) & 0xFF)

/* This array holds the chars that always start a comment.  If the
   pre-processor is disabled, these aren't very useful.  */
const char comment_chars[] = "#";

const char line_separator_chars[] = ";";

/* This array holds the chars that only start a comment at the beginning of
   a line.  */
const char line_comment_chars[] = "#";

const int md_reloc_size = 8; /* Size of relocation record.  */

/* Chars that can be used to separate mant
   from exp in floating point numbers.  */
const char EXP_CHARS[] = "eE";

/* Chars that mean this number is a floating point constant
   As in 0f12.456
   or    0d1.2345e12.  */
const char FLT_CHARS[] = "rRsSfFdDxXpP";

/* INST_PC_OFFSET and INST_NO_OFFSET are 0 and 1.  */
#define UNDEFINED_PC_OFFSET  2
#define DEFINED_ABS_SEGMENT  3
#define DEFINED_PC_OFFSET    4
#define DEFINED_RO_SEGMENT   5
#define DEFINED_RW_SEGMENT   6
#define LARGE_DEFINED_PC_OFFSET 7
#define GOT_OFFSET           8
#define PLT_OFFSET           9
#define GOTOFF_OFFSET        10

#define INST_IMM 0x8000

/* Initialize the relax table.  */
const relax_typeS md_relax_table[] =
{
  {          1,          1,                0, 0 },  /*  0: Unused.  */
  {          1,          1,                0, 0 },  /*  1: Unused.  */
  {          1,          1,                0, 0 },  /*  2: Unused.  */
  {          1,          1,                0, 0 },  /*  3: Unused.  */
  {      32767,   -32768, INST_WORD_SIZE*3, LARGE_DEFINED_PC_OFFSET }, /* 4: DEFINED_PC_OFFSET.  */
  {    1,     1,       0, 0 },                      /*  5: Unused.  */
  {    1,     1,       0, 0 },                      /*  6: Unused.  */
  { 0x7fffffff, 0x80000000, INST_WORD_SIZE*3, 0 },  /*  7: LARGE_DEFINED_PC_OFFSET.  */
  { 0x7fffffff, 0x80000000, INST_WORD_SIZE*3, 0 },  /*  8: GOT_OFFSET.  */
  { 0x7fffffff, 0x80000000, INST_WORD_SIZE*3, 0 },  /*  9: PLT_OFFSET.  */
  { 0x7fffffff, 0x80000000, INST_WORD_SIZE*3, 0 },  /* 10: GOTOFF_OFFSET.  */
};

static bfd_boolean check_gpr_reg (unsigned *p)
{
    if ((*p)<32)
        return 1;
    return 0;
}

static struct hash_control * opcode_hash_control;	/* Opcode mnemonics.  */

void
md_begin (void)
{
  struct op_code_struct * opcode;

  opcode_hash_control = hash_new ();

  /* Insert unique names into hash table.  */
  for (opcode = opcodes; opcode->name; opcode ++)
    hash_insert (opcode_hash_control, opcode->name, (char *) opcode);
}


/* Put number into target byte order.  */

void
md_number_to_chars (char * ptr, valueT use, int nbytes)
{
  if (target_big_endian)
    number_to_chars_bigendian (ptr, use, nbytes);
  else
    number_to_chars_littleendian (ptr, use, nbytes);
}

/* Round up a section size to the appropriate boundary.  */

valueT
md_section_align (segT segment ATTRIBUTE_UNUSED, valueT size)
{
  return size;			/* Byte alignment is fine.  */
}


/* The location from which a PC relative jump should be calculated,
   given a PC relative reloc.  */

long
md_pcrel_from_section (fixS * fixp, segT sec ATTRIBUTE_UNUSED)
{
    printf("md_pcrel_from_section: enter\n");
#ifdef OBJ_ELF
  /* If the symbol is undefined or defined in another section
     we leave the add number alone for the linker to fix it later.
     Only account for the PC pre-bump (No PC-pre-bump on the Microblaze). */

  if (fixp->fx_addsy != (symbolS *) NULL
      && (!S_IS_DEFINED (fixp->fx_addsy)
          || (S_GET_SEGMENT (fixp->fx_addsy) != sec)))
    return 0;
  else
    {
      /* The case where we are going to resolve things... */
      if (fixp->fx_r_type == BFD_RELOC_64_PCREL)
        return  fixp->fx_where + fixp->fx_frag->fr_address + INST_WORD_SIZE*3;
      else
        return  fixp->fx_where + fixp->fx_frag->fr_address + INST_WORD_SIZE*3;
    }
#endif
}

/* This table describes all the machine specific pseudo-ops the assembler
   has to support.  The fields are:
   Pseudo-op name without dot
   Function to call to execute this pseudo-op
   Integer arg to pass to the function.  */
/* If the pseudo-op is not found in this table, it searches in the obj-elf.c,
   and then in the read.c table.  */
const pseudo_typeS md_pseudo_table[] =
{
  {"data8", cons, 1},      /* Same as byte.  */
  {"data16", cons, 2},     /* Same as hword.  */
  {"data32", cons, 4},     /* Same as word.  */
  {"ent", s_func, 0}, /* Treat ent as function entry point.  */
  {"gpword", s_rva, 4}, /* gpword label => store resolved label address in data section.  */
  {"word", cons, 4},
  {"frame", s_ignore, 0},
  {"mask", s_ignore, 0}, /* Emitted by gcc.  */
  {NULL, NULL, 0}
};

#if 0
void
md_operand (expressionS * expressionP)
{
  /* Ignore leading hash symbol, if present.  */
  if (*input_line_pointer == '#')
    {
      input_line_pointer ++;
      expression (expressionP);
    }
}
#endif

extern void
parse_cons_expression_xtc (expressionS *exp, int size)
{
#if 0
  if (size == 4)
    {
      /* Handle @GOTOFF et.al.  */
      char *save, *gotfree_copy;
      int got_len, got_type;

      save = input_line_pointer;

      gotfree_copy = check_got (& got_type, & got_len);
      if (gotfree_copy)
        input_line_pointer = gotfree_copy;

      expression (exp);

      if (gotfree_copy)
	{
          exp->X_md = got_type;
          input_line_pointer = save + (input_line_pointer - gotfree_copy)
	    + got_len;
          free (gotfree_copy);
          }

    }
  else
      expression (exp);
#endif
  if (size<=4)
  expression (exp);
}

symbolS *
md_undefined_symbol (char * name ATTRIBUTE_UNUSED)
{
  return NULL;
}

/* Various routines to kill one day.  */
/* Equal to MAX_PRECISION in atof-ieee.c */
#define MAX_LITTLENUMS 6

/* Turn a string in input_line_pointer into a floating point constant of type
   type, and store the appropriate bytes in *litP.  The number of LITTLENUMS
   emitted is stored in *sizeP.  An error message is returned, or NULL on OK.*/
char *
md_atof (int type, char * litP, int * sizeP)
{
  int prec;
  LITTLENUM_TYPE words[MAX_LITTLENUMS];
  int    i;
  char * t;

  switch (type)
    {
    case 'f':
    case 'F':
    case 's':
    case 'S':
      prec = 2;
      break;

    case 'd':
    case 'D':
    case 'r':
    case 'R':
      prec = 4;
      break;

    case 'x':
    case 'X':
      prec = 6;
      break;

    case 'p':
    case 'P':
      prec = 6;
      break;

    default:
      *sizeP = 0;
      return _("Bad call to MD_NTOF()");
    }

  t = atof_ieee (input_line_pointer, type, words);

  if (t)
    input_line_pointer = t;

  *sizeP = prec * sizeof (LITTLENUM_TYPE);

  if (! target_big_endian)
    {
      for (i = prec - 1; i >= 0; i--)
        {
          md_number_to_chars (litP, (valueT) words[i],
                              sizeof (LITTLENUM_TYPE));
          litP += sizeof (LITTLENUM_TYPE);
        }
    }
  else
    for (i = 0; i < prec; i++)
      {
        md_number_to_chars (litP, (valueT) words[i],
                            sizeof (LITTLENUM_TYPE));
        litP += sizeof (LITTLENUM_TYPE);
      }

  return NULL;
}


const char * md_shortopts = "";

struct option md_longopts[] =
{
  { NULL,          no_argument, NULL, 0}
};

size_t md_longopts_size = sizeof (md_longopts);

int md_short_jump_size;

void
md_create_short_jump (char * ptr ATTRIBUTE_UNUSED,
		      addressT from_Nddr ATTRIBUTE_UNUSED,
		      addressT to_Nddr ATTRIBUTE_UNUSED,
		      fragS * frag ATTRIBUTE_UNUSED,
		      symbolS * to_symbol ATTRIBUTE_UNUSED)
{
  as_fatal (_("failed sanity check: short_jump"));
}

void
md_create_long_jump (char * ptr ATTRIBUTE_UNUSED,
		     addressT from_Nddr ATTRIBUTE_UNUSED,
		     addressT to_Nddr ATTRIBUTE_UNUSED,
		     fragS * frag ATTRIBUTE_UNUSED,
		     symbolS * to_symbol ATTRIBUTE_UNUSED)
{
  as_fatal (_("failed sanity check: long_jump"));
}

int
md_parse_option (int c, char * arg ATTRIBUTE_UNUSED)
{
  switch (c)
    {
    default:
      return 0;
    }
  return 1;
}

void
md_show_usage (FILE * stream ATTRIBUTE_UNUSED)
{
}


/* Try to parse a reg name.  */

static char *
parse_reg (char * s, unsigned * reg)
{
  unsigned tmpreg = 0;

  /* Strip leading whitespace.  */
  while (ISSPACE (* s))
    ++ s;

  if (strncasecmp (s, "pc", 2) == 0)
    {
      *reg = REG_PC;
      return s + 2;
    }
  else if (strncasecmp (s, "y", 1) == 0)
    {
      *reg = REG_Y;
      return s + 1;
    }
  else if (strncasecmp (s, "br", 2) == 0)
    {
      *reg = REG_BR;
      return s + 2;
    }
  else
    {
      if (TOLOWER (s[0]) == 'r')
        {
          if (ISDIGIT (s[1]) && ISDIGIT (s[2]))
            {
              tmpreg = (s[1] - '0') * 10 + s[2] - '0';
              s += 3;
            }
          else if (ISDIGIT (s[1]))
            {
              tmpreg = s[1] - '0';
              s += 2;
            }
          else
            as_bad (_("register expected, but saw '%.6s'"), s);

          if ((int)tmpreg >= MIN_REGNUM && tmpreg <= MAX_REGNUM)
            *reg = tmpreg;
          else
	    {
              as_bad (_("Invalid register number at '%.6s'"), s);
              *reg = 0;
            }
          printf("REG %s -> %d\n", s, *reg);

          return s;
        }
    }
  as_bad (_("register expected, but saw '%.6s'"), s);
  *reg = 0;
  return s;
}



static char *
parse_exp (char *s, expressionS *e)
{
  char *save;
  char *new_pointer;

  /* Skip whitespace.  */
  while (ISSPACE (* s))
    ++ s;

  save = input_line_pointer;
  input_line_pointer = s;

  expression (e);

  if (e->X_op == O_absent)
    as_fatal (_("missing operand"));

  new_pointer = input_line_pointer;
  input_line_pointer = save;

  return new_pointer;
}


static char *
parse_imm (char * s, expressionS * e, int min, int max)
{
  char *new_pointer;
  char *atp;

  /* Find the start of "@GOT" or "@PLT" suffix (if any) */
  for (atp = s; *atp != '@'; atp++)
    if (is_end_of_line[(unsigned char) *atp])
      break;

  if (*atp == '@')
    {
      if (strncmp (atp + 1, "GOTOFF", 5) == 0)
	{
	  *atp = 0;
          //e->X_md = IMM_GOTOFF;
          as_fatal("Cannot handle GOTOFF");
	}
      else if (strncmp (atp + 1, "GOT", 3) == 0)
	{
	  *atp = 0;
          //e->X_md = IMM_GOT;
          as_fatal("Cannot handle GOT");

	}
      else if (strncmp (atp + 1, "PLT", 3) == 0)
	{
	  *atp = 0;
          //e->X_md = IMM_PLT;
          as_fatal("Cannot handle PLT");

	}
      else
	{
	  atp = NULL;
	  e->X_md = 0;
	}
      *atp = 0;
    }
  else
    {
      atp = NULL;
      e->X_md = 0;
    }
      /*
  if (atp && !GOT_symbol)
    {
      GOT_symbol = symbol_find_or_make (GOT_SYMBOL_NAME);
      }

        */
  new_pointer = parse_exp (s, e);

  if (e->X_op == O_absent)
    ; /* An error message has already been emitted.  */
  else if ((e->X_op != O_constant && e->X_op != O_symbol) )
    as_fatal (_("operand must be a constant or a label"));
  else if ((e->X_op == O_constant) && ((int) e->X_add_number < min
				       || (int) e->X_add_number > max))
    {
      as_fatal (_("operand must be absolute in range %d..%d, not %d"),
                min, max, (int) e->X_add_number);
    }
#if 0
  if (atp)
    {
      *atp = '@'; /* restore back (needed?)  */
      if (new_pointer >= atp)
        new_pointer += (e->X_md == IMM_GOTOFF)?7:4;
      /* sizeof("@GOTOFF", "@GOT" or "@PLT") */

    }
#endif
  return new_pointer;
}

/* Try to parse a memory address  */

static char *
parse_memory (char * s, unsigned * ptr_reg, int *hasimm, expressionS *imval)
{
  /* Strip leading whitespace.  */
  while (ISSPACE (* s))
    ++ s;

  printf("parse_memory: parsing %s\n", s);

  if ( *s == '(' ) {
      s++;
      /* First argument must be a register */
      printf("Calling parsereg with '%s'\n",s);
      s = parse_reg(s, ptr_reg);
      if (!check_gpr_reg(ptr_reg)) {
          as_fatal("Only GPR registers allowed");
      }
      while (ISSPACE (* s))
          ++ s;
      /* Operand must either be a sum with an immediate,
       or empty */
      if (*s == ')') {
          if (hasimm)
              *hasimm = 0; // No immediate;
          printf("No immediate, it's OK\n");
          s++;
          return s;
      } else {
          printf("Parse IMM: %s\n",s);
          s = parse_imm( s, imval, MIN_IMM, MAX_IMM );
          if (hasimm) {
              *hasimm = 1;
          }

          while (ISSPACE (* s))
              ++ s;
          if (*s == ')') {
              s++;
              return s;
          }
      }
  }
  as_fatal (_("Memory address expected, but saw '%s'"), s);
  return s;
}


static int xtc_count_bits(unsigned int immed)
{
    int count=31;
    int bsign;
    int sign = !!(immed & 0x80000000);
    do {
        immed<<=1;
        bsign = !!(immed&0x80000000);
        if (bsign!=sign)
            break;
    } while (--count);
    return count+1;
}
static inline int xtc_can_represent_as_imm8(int immed)
{
    return immed <= 127 && immed >= -128;
}
#if 0
static int xtc_bytes_12_12_8(long int value)
{
    if ((value & 0xfff80000)==0 /* unsigned */
        ||(value & 0xfff80000)==0xfff80000 /* signed */ ) {

        /* Two bytes (12+8) or one. */
        if (((value & 0xffffff80) == 0) ||
            (value & 0xffffff80) == 0xffffff80 ) {
            /* A single byte will do it */
            return 1;
        }
        return 2;
    } else {
        return 3;
    }
}
#endif

static int xtc_bytes_12_12_12(long int value)
{
    if ((value & 0xff800000)==0 /* unsigned */
        ||(value & 0xff800000)==0xff800000 /* signed */ ) {

        /* Two bytes (12+12) or one. */
        if (((value & 0xfffff800) == 0) ||
            (value & 0xfffff800) == 0xfffff800 ) {
            /* A single byte will do it */
            return 1;
        }
        return 2;
    } else {
        return 3;
    }
}
#if 0
static char *xtc_frag_fixed_immed(long int value)
{
    // 000 000
    fprintf(stderr, "FIXED immed: %ld\n",value);
    char *o;
    int i;
    for (i=0;i<3;i++) {
        o = frag_more(2);
        o[0] = 0x80 | ((value >>20)&0xf);
        o[1] = (value>>16) & 0xff;
        value<<=12;
    }
    return o;
}
#endif

static void xtc_emit_imm_12(int value, unsigned op)
{
    op &= ~0x0FFF;
    op |= (value)&0x0FFF;
    char *output = frag_more(2);
    output[0] = op>>8;
    output[1] = op;
}
#if 0
static void xtc_emit_imm_8(long int value, unsigned op)
{
    op &= ~0x0FF0;
    op |= (value<<4)&0xFF;
    char *output = frag_more(2);
    output[0] = op>>8;
    output[1] = op;
}
#endif

static void xtc_emit_imm_12_12(long int value, unsigned op)
{
    xtc_emit_imm_12(value>>12, INST_IMM);
    xtc_emit_imm_12(value, op);
}

static void xtc_emit_imm_12_12_12(long int value, unsigned op)
{
    xtc_emit_imm_12(value>>24, INST_IMM);
    xtc_emit_imm_12(value>>12, INST_IMM);
    xtc_emit_imm_12(value, op);
}
#if 0
static void xtc_emit_imm_12_8(long int value, unsigned op)
{
    xtc_emit_imm_12(value>>8, INST_IMM);
    xtc_emit_imm_8(value, op);
}

static void xtc_emit_imm_12_12_8(long int value, unsigned op)
{
    xtc_emit_imm_12(value>>20, INST_IMM);
    xtc_emit_imm_12(value>>8, INST_IMM);
    xtc_emit_imm_8(value, op);
}
#endif

static void xtc_emit_imm_121212(long int value, unsigned op, int size)
{
    switch(size) {
    case 3:
        xtc_emit_imm_12_12_12(value,op);
        break;
    case 2:
        xtc_emit_imm_12_12(value,op);
        break;
    case 1:
        xtc_emit_imm_12(value,op);
        break;
    default:
        abort();
    }
}
#if 0
static void xtc_emit_imm_12128(long int value, unsigned op, int size)
{
    switch(size) {
    case 3:
        xtc_emit_imm_12_12_8(value,op);
        break;
    case 2:
        xtc_emit_imm_12_8(value,op);
        break;
    case 1:
        xtc_emit_imm_8(value,op);
        break;
    default:
        abort();
    }
}
#endif

void
md_assemble (char * str)
{
    char * op_start;
    char * op_end;
    struct op_code_struct * opcode, *opcode1;
    char * output = NULL;
    int nlen = 0;
    //int i;
    unsigned long inst, inst1;
    unsigned reg1;
    unsigned reg2;
    //unsigned reg3;
    int hasimm;
    unsigned isize;
    unsigned int immed, temp;
    expressionS exp;
    char name[20];

    /* Drop leading whitespace.  */
    while (ISSPACE (* str))
        str ++;

    /* Find the op code end.  */
    for (op_start = op_end = str;
         *op_end && !is_end_of_line[(unsigned char) *op_end] && *op_end != ' ';
         op_end++)
    {
        name[nlen] = op_start[nlen];
        nlen++;
        if (nlen == sizeof (name) - 1)
            break;
    }

    name [nlen] = 0;

    if (nlen == 0)
    {
        as_bad (_("can't find opcode "));
        return;
    }

    opcode = (struct op_code_struct *) hash_find (opcode_hash_control, name);
    if (opcode == NULL)
    {
        as_bad (_("unknown opcode \"%s\""), name);
        return;
    }

    inst = opcode->bit_sequence;
    printf("At start: bit sequence %04lx\n", opcode->bit_sequence);
    isize = 2;

    //int ismem = 0;

    switch (opcode->inst_type)
    {

    case INST_TYPE_SR:

        if (strcmp (op_end, ""))
            op_end = parse_reg (op_end + 1, &reg1);  /* Get r1.  */
        else
        {
            as_fatal (_("Error in statement syntax"));
            reg1 = 0;
        }
        if (strcmp (op_end, ""))
            op_end = parse_reg (op_end + 1, &reg2);  /* Get r2  */
        else
        {
            as_fatal (_("Error in statement syntax"));
            reg2 = 0;
        }
        printf("R1 %d, R2 %d\n", reg1, reg2);
        /* Check for spl registers.  */
        if (!check_gpr_reg (& reg1))
            as_fatal (_("Cannot use special register with this instruction"));

        if (check_gpr_reg (& reg2))
            as_fatal (_("Cannot use GPR register with this instruction"));

        inst |= (reg1 << RA_LOW) & RA_MASK;
        inst |= ((reg2-32) << SPR_LOW) & SPR_MASK;
        printf("now: bit sequence %04lx\n", inst);

        output = frag_more (isize);
        break;

    case INST_TYPE_MEM:

        switch (opcode->instr_type) {
        case memory_store_inst:

            if (strcmp (op_end, ""))
                op_end = parse_reg (op_end + 1, &reg2);  /* Get r2  */
            else
            {
                as_fatal (_("Error in statement syntax"));
                reg2 = 0;
            }
            /* Memory instructions include a displacement */
            op_end = parse_memory(op_end+1, &reg1, &hasimm, &exp);

            break;
        case memory_load_inst:

            op_end = parse_memory(op_end+1, &reg1, &hasimm, &exp);

            if (strcmp (op_end, ""))
                op_end = parse_reg (op_end + 1, &reg2);  /* Get r2  */
            else
            {
                as_fatal (_("Error in statement syntax"));
                reg2 = 0;
            }
            break;
        default:
            as_fatal("Internal bug");
            break;
        }
        inst |= (reg1 << RA_LOW) & RA_MASK;
        inst |= (reg2 << RB_LOW) & RB_MASK;
        printf("Opcode for mem: %04lx\n", inst);

        /* Check for spl registers.  */
        if (!check_gpr_reg (& reg2))
            as_fatal (_("Cannot use special register with this instruction"));

        /* Now, check if we need to add a displacement */
        if (hasimm==1) {
            if (exp.X_op != O_constant) {


                int newReloc = BFD_RELOC_XTC_IMM_12_12_12;
    
                fix_new_exp (frag_now, frag_now_fix (), 6, &exp, 0, newReloc);
                xtc_emit_imm_12_12_12(0, INST_IMM);
                output = frag_more(INST_WORD_SIZE);
                output[0] = INST_BYTE0(inst);
                output[1] = INST_BYTE1(inst);

                return;
                //as_bad("Cannot yet handle offsets in memory access");
            } else {
                if (exp.X_add_number!=0)
                    xtc_emit_imm_121212( exp.X_add_number, INST_IMM, xtc_bytes_12_12_12(exp.X_add_number) );

                output = frag_more(INST_WORD_SIZE);
                output[0] = INST_BYTE0(inst);
                output[1] = INST_BYTE1(inst);
                return;
                //as_bad("Missing constants for memory");
            }
        }

        printf("now: bit sequence %04lx\n", inst);

        output = frag_more (isize);
        break;



    case INST_TYPE_R1_R2:

        if (strcmp (op_end, ""))
            op_end = parse_reg (op_end + 1, &reg1);  /* Get r1.  */
        else
        {
            as_fatal (_("Error in statement syntax"));
            reg1 = 0;
        }
        if (strcmp (op_end, ""))
            op_end = parse_reg (op_end + 1, &reg2);  /* Get r2  */
        else
        {
            as_fatal (_("Error in statement syntax"));
            reg2 = 0;
        }

        /* Check for spl registers.  */
        if (!check_gpr_reg (& reg1))
            as_fatal (_("Cannot use special register with this instruction"));
        if (!check_gpr_reg (& reg2))
            as_fatal (_("Cannot use special register with this instruction"));

        inst |= (reg1 << RA_LOW) & RA_MASK;
        inst |= (reg2 << RB_LOW) & RB_MASK;
        printf("now: bit sequence %04lx\n", inst);

        output = frag_more (isize);
        break;

    case INST_TYPE_IMM8:
        if (strcmp (op_end, ""))
            op_end = parse_imm (op_end + 1, & exp, MIN_IMM, MAX_IMM);
        else
            as_fatal (_("Error in statement syntax"));

        if (exp.X_op != O_constant)
        {
            int newReloc = (opcode->inst_offset_type == INST_PC_OFFSET ? BFD_RELOC_XTC_IMM_12_12_8_PCREL:
                            BFD_RELOC_XTC_IMM_12_12_8 );

            fix_new_exp (frag_now, frag_now_fix (), 4, &exp, 1, newReloc);
            output = frag_more(2);

            output[0] = 0x80;
            output[1] = 0x0;
            output = frag_more(2*INST_WORD_SIZE);
            output[0] = 0x80;
            output[1] = 0x00;
            output[2] = INST_BYTE0(inst);
            output[3] = INST_BYTE1(inst);

            return;

            immed = 0;
        }
        else
        {
            abort();
            output = frag_more (isize);
            immed = exp.X_add_number;
        }

        temp = immed & 0xFFFF8000;
        if ((temp != 0) && (temp != 0xFFFF8000))
        {
            /* Needs an immediate inst.  */
            opcode1 = (struct op_code_struct *) hash_find (opcode_hash_control, "imm");
            if (opcode1 == NULL)
            {
                as_bad (_("unknown opcode \"%s\""), "imm");
                return;
            }

            inst1 = opcode1->bit_sequence;
            inst1 |= ((immed & 0xFFFF0000) >> 16) & IMM_MASK;
            output[0] = INST_BYTE0 (inst1);
            output[1] = INST_BYTE1 (inst1);
            output = frag_more (isize);
        }
        inst |= (immed << IMM_LOW) & IMM_MASK;
        //output = frag_more(isize*2);
        break;

    case INST_TYPE_IMM:
        if (strcmp (op_end, ""))
            op_end = parse_imm (op_end + 1, & exp, MIN_IMM, MAX_IMM);
        else
            as_fatal (_("Error in statement syntax"));

        as_fatal("NYI");

        if (exp.X_op != O_constant)
        {
            as_fatal("Dont know how to handle this");
            immed = 0;
        }
        else
        {
            output = frag_more (isize);
            immed = exp.X_add_number;
        }


        temp = immed & 0xFFFF8000;
        if ((temp != 0) && (temp != 0xFFFF8000))
        {
            /* Needs an immediate inst.  */
            opcode1 = (struct op_code_struct *) hash_find (opcode_hash_control, "imm");
            if (opcode1 == NULL)
            {
                as_bad (_("unknown opcode \"%s\""), "imm");
                return;
            }

            inst1 = opcode1->bit_sequence;
            inst1 |= ((immed & 0xFFFF0000) >> 16) & IMM_MASK;
            output[0] = INST_BYTE0 (inst1);
            output[1] = INST_BYTE1 (inst1);
            output = frag_more (isize);
        }
        inst |= (immed << IMM_LOW) & IMM_MASK;

        break;

    case INST_TYPE_IMM8_R:

        if (strcmp (op_end, ""))
            op_end = parse_imm (op_end + 1, & exp, MIN_IMM, MAX_IMM);
        else
            as_fatal (_("Error in statement syntax"));

        if (strcmp (op_end, ""))
            op_end = parse_reg (op_end + 1, &reg1);  /* Get r1.  */
        else
        {
            as_fatal (_("Error in statement syntax"));
            reg1 = 0;
        }
        /* Check for spl registers.  */
        if (!check_gpr_reg (&reg1))
            as_fatal (_("Cannot use special register with this instruction"));

        inst |= (reg1 << RA_LOW) & RA_MASK;

        if (exp.X_op != O_constant)
        {
#if 0
            char *opc = NULL;
            relax_substateT subtype = opcode->inst_offset_type;

            printf("Call FRAG var\n");
            output = frag_var (rs_machine_dependent,
                               isize, /* maxm of 3 words.  */
                               isize,     /* minm of 1 word.  */
                               subtype,   /* PC-relative or not.  */
                               exp.X_add_symbol,
                               exp.X_add_number,
                               opc);
#endif
            int newReloc = (opcode->inst_offset_type == INST_PC_OFFSET ? BFD_RELOC_XTC_IMM_12_12_8_PCREL:
                            BFD_RELOC_XTC_IMM_12_12_8 );

            fix_new_exp (frag_now, frag_now_fix (), 4, &exp, 1, newReloc);
            output = frag_more(2);

            output[0] = 0x80;
            output[1] = 0x0;
            output = frag_more(2*INST_WORD_SIZE);
            output[0] = 0x80;
            output[1] = 0x00;
            output[2] = INST_BYTE0(inst);
            output[3] = INST_BYTE1(inst);
            printf("EMIT INST %04lx\n",inst);
            return;
            immed = 0;
            abort();
        }
        else
        {
            int bits = xtc_count_bits(exp.X_add_number);

            output = frag_more (isize);
            printf("Need to emit constant IMM, value %08x\n", (unsigned)exp.X_add_number);
            immed = exp.X_add_number >> 8;

            if (bits>=20) {
                // emit very high IM12
                unsigned inst2;
                // this is WRONG - we're outputting high values
                // and not the correct ones.

                inst2 = 0x8000 | (((immed>>12) << IMM_LOW) & IMM_MASK);
                printf("IMM EMIT %04x\n",inst2);
                output[0] = INST_BYTE0 (inst2);
                output[1] = INST_BYTE1 (inst2);
                dwarf2_emit_insn (2);

                output = frag_more (isize);
                immed<<=12;
                bits-=12;
            }
            if (bits>8) {
                // emit very high IM12
                unsigned inst2;
                inst2 = 0x8000 | (((immed) << IMM_LOW) & IMM_MASK);
                printf("IMM EMIT %04x\n",inst2);
                output[0] = INST_BYTE0 (inst2);
                output[1] = INST_BYTE1 (inst2);
                dwarf2_emit_insn (2);
                output = frag_more (isize);
                bits-=8;
            }

            inst |= (reg1 << RA_LOW) & RA_MASK;
            inst |= (exp.X_add_number << IMM8_LOW) & IMM8_MASK;
            printf("IMM EMIT %04lx\n",inst);
                
            output[0] = INST_BYTE0 (inst);
            output[1] = INST_BYTE1 (inst);
            //output = frag_more (isize);

            //abort();
        }

        break;

    case INST_TYPE_NOARGS:
        output = frag_more (isize);
        break;

    default:
        as_fatal (_("BUG: unimplemented opcode \"%s\" typed %d"), name, opcode->inst_type);
    }

    /* Drop whitespace after all the operands have been parsed.  */
    while (ISSPACE (* op_end))
        op_end ++;

    /* Give warning message if the insn has more operands than required.  */
    if (strcmp (op_end, opcode->name) && strcmp (op_end, ""))
        as_warn (_("ignoring operands: %s "), op_end);

    printf("outputting %02lx%02lx\n", INST_BYTE0(inst),INST_BYTE1(inst));
    output[0] = INST_BYTE0 (inst);
    output[1] = INST_BYTE1 (inst);

#ifdef OBJ_ELF
    dwarf2_emit_insn (2);
#endif
}

/* Called after relaxing, change the frags so they know how big they are.  */

void
md_convert_frag (bfd * abfd ATTRIBUTE_UNUSED,
                 segT sec ATTRIBUTE_UNUSED,
                 fragS * fragP)
{
    //fixS *fixP;

    printf("md_convert_frag: converting frag subtype %d, fix at %lu\n", fragP->fr_subtype,
           fragP->fr_fix);

    switch (fragP->fr_subtype)
    {
    case UNDEFINED_PC_OFFSET:
        printf("md_convert_frag: undefined PC offset\n");

        fix_new (fragP, fragP->fr_fix, INST_WORD_SIZE * 3, fragP->fr_symbol,
                 fragP->fr_offset, TRUE, BFD_RELOC_XTC_IMM_12_12_8);
        fragP->fr_fix += INST_WORD_SIZE * 2;
        fragP->fr_var = 0;
        //abort();
        break;

    case DEFINED_ABS_SEGMENT:
        printf("md_convert_frag: defined ABS segment\n");

        //if (fragP->fr_symbol == GOT_symbol) {
        //    as_fatal("md_convert_frag: GOT not supported");
        //}

        fix_new (fragP, fragP->fr_fix, INST_WORD_SIZE, fragP->fr_symbol,
                 fragP->fr_offset, FALSE, BFD_RELOC_XTC_IMM_12_12_8);
        fragP->fr_fix += INST_WORD_SIZE * 2;
        fragP->fr_var = 0;
        break;


    case DEFINED_PC_OFFSET:

        printf("md_convert_frag: defined PC offset  -reloc type %d\n", BFD_RELOC_XTC_IMM_12_12_8_PCREL);

        //fragP->fr_fix += INST_WORD_SIZE*2;
        //fragP->fr_fix -= 4;

        fix_new (fragP, fragP->fr_fix, INST_WORD_SIZE*3, fragP->fr_symbol,
                 fragP->fr_offset, TRUE, BFD_RELOC_XTC_IMM_12_12_8_PCREL);

        fragP->fr_fix += INST_WORD_SIZE * 2;

        fragP->fr_var = 0;
        break;

    default:

        as_fatal("dont know how to convert_frag %d", fragP->fr_subtype);
    }

#if 0
case DEFINED_ABS_SEGMENT:
    if (fragP->fr_symbol == GOT_symbol)
        fix_new (fragP, fragP->fr_fix, INST_WORD_SIZE * 2, fragP->fr_symbol,
                 fragP->fr_offset, TRUE, BFD_RELOC_MICROBLAZE_64_GOTPC);
    else
        fix_new (fragP, fragP->fr_fix, INST_WORD_SIZE * 2, fragP->fr_symbol,
                 fragP->fr_offset, FALSE, BFD_RELOC_64);
    fragP->fr_fix += INST_WORD_SIZE * 2;
    fragP->fr_var = 0;
    break;
case DEFINED_RO_SEGMENT:
    fix_new (fragP, fragP->fr_fix, INST_WORD_SIZE, fragP->fr_symbol,
             fragP->fr_offset, FALSE, BFD_RELOC_MICROBLAZE_32_ROSDA);
    fragP->fr_fix += INST_WORD_SIZE;
    fragP->fr_var = 0;
    break;
case DEFINED_RW_SEGMENT:
    fix_new (fragP, fragP->fr_fix, INST_WORD_SIZE, fragP->fr_symbol,
             fragP->fr_offset, FALSE, BFD_RELOC_MICROBLAZE_32_RWSDA);
    fragP->fr_fix += INST_WORD_SIZE;
    fragP->fr_var = 0;
    break;
case DEFINED_PC_OFFSET:
    fix_new (fragP, fragP->fr_fix, INST_WORD_SIZE, fragP->fr_symbol,
             fragP->fr_offset, TRUE, BFD_RELOC_MICROBLAZE_32_LO_PCREL);
    fragP->fr_fix += INST_WORD_SIZE;
    fragP->fr_var = 0;
    break;
case LARGE_DEFINED_PC_OFFSET:
    fix_new (fragP, fragP->fr_fix, INST_WORD_SIZE * 2, fragP->fr_symbol,
             fragP->fr_offset, TRUE, BFD_RELOC_64_PCREL);
    fragP->fr_fix += INST_WORD_SIZE * 2;
    fragP->fr_var = 0;
    break;
case GOT_OFFSET:
    fix_new (fragP, fragP->fr_fix, INST_WORD_SIZE * 2, fragP->fr_symbol,
             fragP->fr_offset, FALSE, BFD_RELOC_MICROBLAZE_64_GOT);
    fragP->fr_fix += INST_WORD_SIZE * 2;
    fragP->fr_var = 0;
    break;
case PLT_OFFSET:
    fixP = fix_new (fragP, fragP->fr_fix, INST_WORD_SIZE * 2, fragP->fr_symbol,
                    fragP->fr_offset, TRUE, BFD_RELOC_MICROBLAZE_64_PLT);
    /* fixP->fx_plt = 1; */
    (void) fixP;
    fragP->fr_fix += INST_WORD_SIZE * 2;
    fragP->fr_var = 0;
    break;
case GOTOFF_OFFSET:
    fix_new (fragP, fragP->fr_fix, INST_WORD_SIZE * 2, fragP->fr_symbol,
             fragP->fr_offset, FALSE, BFD_RELOC_MICROBLAZE_64_GOTOFF);
    fragP->fr_fix += INST_WORD_SIZE * 2;
    fragP->fr_var = 0;
    break;

default:
    abort ();
}
#endif
}

/* Create a fixup for a cons expression.  If parse_cons_expression_microblaze
 found a machine specific op in an expression,
 then we create relocs accordingly.  */

void
cons_fix_new_xtc (fragS * frag,
			 int where,
			 int size,
			 expressionS *exp)
{

  bfd_reloc_code_real_type r;

#if 0

  if ((exp->X_op == O_subtract) && (exp->X_add_symbol) &&
      (exp->X_op_symbol) && (now_seg != absolute_section) && (size == 4)
      && (!S_IS_LOCAL (exp->X_op_symbol)))
    r = BFD_RELOC_MICROBLAZE_32_SYM_OP_SYM;
  else if (exp->X_md == IMM_GOTOFF && exp->X_op == O_symbol_rva)
    {
      exp->X_op = O_symbol;
      r = BFD_RELOC_MICROBLAZE_32_GOTOFF;
    }
  else
    {
#endif

        switch (size)
        {
        case 1:
          r = BFD_RELOC_8;
          break;
        case 2:
          r = BFD_RELOC_16;
          break;
        case 4:
          r = BFD_RELOC_32;
          break;
        case 8:
          r = BFD_RELOC_64;
          break;
        default:
          as_bad (_("unsupported BFD relocation size %u"), size);
          r = BFD_RELOC_32;
          break;
        }
        printf("cons_fix_new_xtc: %d\n", r);
#if 0
    }
#endif
  fix_new_exp (frag, where, size, exp, 0, r);
}
#if 0
int
tc_xtc_fix_adjustable (struct fix *fixP ATTRIBUTE_UNUSED)
{
    printf("tc_xtc_fix_adjustable: enter\n");
#if 0
  if (GOT_symbol && fixP->fx_subsy == GOT_symbol)
    return 0;

  if (fixP->fx_r_type == BFD_RELOC_MICROBLAZE_64_GOTOFF
      || fixP->fx_r_type == BFD_RELOC_MICROBLAZE_32_GOTOFF
      || fixP->fx_r_type == BFD_RELOC_MICROBLAZE_64_GOT
      || fixP->fx_r_type == BFD_RELOC_MICROBLAZE_64_PLT)
    return 0;
#endif
  return 1;
}
#endif

#define F(SZ,PCREL)		(((SZ) << 1) + (PCREL))
#define MAP(SZ,PCREL,TYPE)	case F (SZ, PCREL): code = (TYPE); break

arelent *
tc_gen_reloc (asection * section ATTRIBUTE_UNUSED, fixS * fixp)
{
  arelent * rel;
  bfd_reloc_code_real_type code;

  printf("tc_gen_reloc: called, type %d size %d pcrel %d\n", fixp->fx_r_type, fixp->fx_size,
        fixp->fx_pcrel);

  switch (fixp->fx_r_type)
    {
    case BFD_RELOC_NONE:
    case BFD_RELOC_32:
    case BFD_RELOC_64:
    case BFD_RELOC_64_PCREL:
    case BFD_RELOC_XTC_32:
    case BFD_RELOC_XTC_32_PCREL:
    case BFD_RELOC_XTC_IMM_12_12_8:
    case BFD_RELOC_XTC_IMM_12_8:
    case BFD_RELOC_XTC_IMM_8:
    case BFD_RELOC_XTC_IMM_12_12_12:
    case BFD_RELOC_XTC_IMM_12_12:
    case BFD_RELOC_XTC_IMM_12:
    case BFD_RELOC_XTC_IMM_12_12_8_PCREL:
    case BFD_RELOC_XTC_IMM_12_8_PCREL:
    case BFD_RELOC_XTC_IMM_8_PCREL:
        printf("Copy type\n");
        code = fixp->fx_r_type;
        break;

    default:
        abort();
      switch (F (fixp->fx_size, fixp->fx_pcrel))
        {
          MAP (1, 0, BFD_RELOC_8);
          MAP (2, 0, BFD_RELOC_16);
          MAP (4, 0, BFD_RELOC_32);
          MAP (1, 1, BFD_RELOC_8_PCREL);
          MAP (2, 1, BFD_RELOC_16_PCREL);
          MAP (4, 1, BFD_RELOC_32_PCREL);
        default:
          code = fixp->fx_r_type;
          as_bad (_("Can not do %d byte %srelocation"),
                  fixp->fx_size,
                  fixp->fx_pcrel ? _("pc-relative") : "");
        }
      break;
    }

  rel = (arelent *) xmalloc (sizeof (arelent));
  rel->sym_ptr_ptr = (asymbol **) xmalloc (sizeof (asymbol *));
#if 0

  if (code == BFD_RELOC_MICROBLAZE_32_SYM_OP_SYM)
    *rel->sym_ptr_ptr = symbol_get_bfdsym (fixp->fx_subsy);
  else
#endif
    *rel->sym_ptr_ptr = symbol_get_bfdsym (fixp->fx_addsy);

  rel->address = fixp->fx_frag->fr_address + fixp->fx_where;
  /* Always pass the addend along!  */
  rel->addend = fixp->fx_offset;

  printf("GEN RELOC: addend is %ld\n", (long)fixp->fx_offset);

  rel->howto = bfd_reloc_type_lookup (stdoutput, code);

  if (rel->howto == NULL)
    {
#if 0
        as_bad_where (fixp->fx_file, fixp->fx_line,
                    as_bad_where (fixp->fx_file, fixp->fx_line,
                                  "Cannot represent relocation type %s",
                                  bfd_get_reloc_code_name (code)));
#endif
        abort();
        /* Set howto to a garbage value so that we can keep going.  */
      rel->howto = bfd_reloc_type_lookup (stdoutput, BFD_RELOC_32);
      gas_assert (rel->howto != NULL);
    }
  return rel;
}


/* Applies the desired value to the specified location.
   Also sets up addends for 'rela' type relocations.  */
void
md_apply_fix (fixS *   fixP,
	      valueT * valp,
	      segT     segment)
{
  char *       buf  = fixP->fx_where + fixP->fx_frag->fr_literal;
  //char *       file = fixP->fx_file ? fixP->fx_file : _("unknown");
  //const char * symname;
  /* Note: use offsetT because it is signed, valueT is unsigned.  */
  offsetT      val  = (offsetT) * valp;
  int          i;
  struct op_code_struct * opcode1;
  unsigned long inst1;

  printf("md_apply_fix: Applying fixup\n");

  //symname = fixP->fx_addsy ? S_GET_NAME (fixP->fx_addsy) : _("<unknown>");

  /* fixP->fx_offset is supposed to be set up correctly for all
   symbol relocations.  */

  if (fixP->fx_addsy == NULL)
    {
         if (!fixP->fx_pcrel)
        fixP->fx_offset = val; /* Absolute relocation.  */
      else
        fprintf (stderr, "NULL symbol PC-relative relocation? offset = %08x, val = %08x\n",
                 (unsigned int) fixP->fx_offset, (unsigned int) val);
    }

  /* If we aren't adjusting this fixup to be against the section
     symbol, we need to adjust the value.  */
  if (fixP->fx_addsy != NULL)
    {
      if (S_IS_WEAK (fixP->fx_addsy)
	  || (symbol_used_in_reloc_p (fixP->fx_addsy)
	      && (((bfd_get_section_flags (stdoutput,
					   S_GET_SEGMENT (fixP->fx_addsy))
		    & SEC_LINK_ONCE) != 0)
		  || !strncmp (segment_name (S_GET_SEGMENT (fixP->fx_addsy)),
			       ".gnu.linkonce",
			       sizeof (".gnu.linkonce") - 1))))
	{
	  val -= S_GET_VALUE (fixP->fx_addsy);
	  if (val != 0 && ! fixP->fx_pcrel)
            {
              /* In this case, the bfd_install_relocation routine will
                 incorrectly add the symbol value back in.  We just want
                 the addend to appear in the object file.
	         FIXME: If this makes VALUE zero, we're toast.  */
              val -= S_GET_VALUE (fixP->fx_addsy);
            }
	}
    }

  /* If the fix is relative to a symbol which is not defined, or not
     in the same segment as the fix, we cannot resolve it here.  */
  /* fixP->fx_addsy is NULL if valp contains the entire relocation.  */
  if (fixP->fx_addsy != NULL
      && (!S_IS_DEFINED (fixP->fx_addsy)
          || (S_GET_SEGMENT (fixP->fx_addsy) != segment)))
    {
        fixP->fx_done = 0;
        printf("md_apply_fix: no defined symbol, or different segment\n");
#ifdef OBJ_ELF
      /* For ELF we can just return and let the reloc that will be generated
         take care of everything.  For COFF we still have to insert 'val'
         into the insn since the addend field will be ignored.  */
      /* return; */
#endif
    }
  /* All fixups in the text section must be handled in the linker.  */
  else if (segment->flags & SEC_CODE) {
      printf("md_apply_fix: text section fixup is for linker\n");
      fixP->fx_done = 0;
  }
  else if (!fixP->fx_pcrel && fixP->fx_addsy != NULL)
    fixP->fx_done = 0;
  else
    fixP->fx_done = 1;

  printf("md_apply_fix: at this point, fix_done == %d\n", fixP->fx_done);

  switch (fixP->fx_r_type)
    {
    case BFD_RELOC_XTC_32_PCREL:
    case BFD_RELOC_XTC_32:
        abort();
        if (target_big_endian)
	{
	  buf[2] |= ((val >> 8) & 0xff);
	  buf[3] |= (val & 0xff);
	}
      else
	{
	  buf[1] |= ((val >> 8) & 0xff);
	  buf[0] |= (val & 0xff);
	}
      break;
#if 0
    case BFD_RELOC_MICROBLAZE_32_ROSDA:
    case BFD_RELOC_MICROBLAZE_32_RWSDA:
      /* Don't do anything if the symbol is not defined.  */
      if (fixP->fx_addsy == NULL || S_IS_DEFINED (fixP->fx_addsy))
	{
	  if (((val & 0xFFFF8000) != 0) && ((val & 0xFFFF8000) != 0xFFFF8000))
	    as_bad_where (file, fixP->fx_line,
			  _("pcrel for branch to %s too far (0x%x)"),
			  symname, (int) val);
	  if (target_big_endian)
	    {
	      buf[2] |= ((val >> 8) & 0xff);
	      buf[3] |= (val & 0xff);
	    }
	  else
	    {
	      buf[1] |= ((val >> 8) & 0xff);
	      buf[0] |= (val & 0xff);
	    }
	}
      break;
#endif
    case BFD_RELOC_32:
    case BFD_RELOC_RVA:
    case BFD_RELOC_32_PCREL:
        abort();
    //case BFD_RELOC_MICROBLAZE_32_SYM_OP_SYM:
      /* Don't do anything if the symbol is not defined.  */
      if (fixP->fx_addsy == NULL || S_IS_DEFINED (fixP->fx_addsy))
	{
	  if (target_big_endian)
	    {
	      buf[0] |= ((val >> 24) & 0xff);
	      buf[1] |= ((val >> 16) & 0xff);
	      buf[2] |= ((val >> 8) & 0xff);
	      buf[3] |= (val & 0xff);
	    }
	  else
	    {
	      buf[3] |= ((val >> 24) & 0xff);
	      buf[2] |= ((val >> 16) & 0xff);
	      buf[1] |= ((val >> 8) & 0xff);
	      buf[0] |= (val & 0xff);
	    }
	}
      break;
    case BFD_RELOC_64_PCREL:
    case BFD_RELOC_64:
      /* Add an imm instruction.  First save the current instruction.  */
      for (i = 0; i < INST_WORD_SIZE; i++)
	buf[i + INST_WORD_SIZE] = buf[i];

      /* Generate the imm instruction.  */
      opcode1 = (struct op_code_struct *) hash_find (opcode_hash_control, "imm");
      if (opcode1 == NULL)
	{
	  as_bad (_("unknown opcode \"%s\""), "imm");
	  return;
	}

      inst1 = opcode1->bit_sequence;
      if (fixP->fx_addsy == NULL || S_IS_DEFINED (fixP->fx_addsy))
	inst1 |= ((val & 0xFFFF0000) >> 16) & IMM_MASK;

      buf[0] = INST_BYTE0 (inst1);
      buf[1] = INST_BYTE1 (inst1);
      //buf[2] = INST_BYTE2 (inst1);
      //buf[3] = INST_BYTE3 (inst1);

      /* Add the value only if the symbol is defined.  */
      if (fixP->fx_addsy == NULL || S_IS_DEFINED (fixP->fx_addsy))
	{
	  if (target_big_endian)
	    {
	      buf[6] |= ((val >> 8) & 0xff);
	      buf[7] |= (val & 0xff);
	    }
	  else
	    {
	      buf[5] |= ((val >> 8) & 0xff);
	      buf[4] |= (val & 0xff);
	    }
	}
      break;
#if 0
    case BFD_RELOC_MICROBLAZE_64_GOTPC:
    case BFD_RELOC_MICROBLAZE_64_GOT:
    case BFD_RELOC_MICROBLAZE_64_PLT:
    case BFD_RELOC_MICROBLAZE_64_GOTOFF:
      /* Add an imm instruction.  First save the current instruction.  */
      for (i = 0; i < INST_WORD_SIZE; i++)
	buf[i + INST_WORD_SIZE] = buf[i];

      /* Generate the imm instruction.  */
      opcode1 = (struct op_code_struct *) hash_find (opcode_hash_control, "imm");
      if (opcode1 == NULL)
	{
	  as_bad (_("unknown opcode \"%s\""), "imm");
	  return;
	}

      inst1 = opcode1->bit_sequence;

      /* We can fixup call to a defined non-global address
	 within the same section only.  */
      buf[0] = INST_BYTE0 (inst1);
      buf[1] = INST_BYTE1 (inst1);
      buf[2] = INST_BYTE2 (inst1);
      buf[3] = INST_BYTE3 (inst1);
      return;
#endif
    default:
      break;
    }
  printf("md_apply_fix: at this point, fx_addsy %p\n", fixP->fx_addsy);
  if (fixP->fx_addsy == NULL)
    {
      /* This fixup has been resolved.  Create a reloc in case the linker
	 moves code around due to relaxing.  */
        if (fixP->fx_r_type == BFD_RELOC_64_PCREL) {
              as_fatal("Cannot handle this");
            //fixP->fx_r_type = BFD_RELOC_MICROBLAZE_64_NONE;
        }
      //else
	//fixP->fx_r_type = BFD_RELOC_NONE;
      //fixP->fx_addsy = section_symbol (absolute_section);
    }
  return;
}



/* Called just before address relaxation, return the length
   by which a fragment must grow to reach it's destination.  */

int
md_estimate_size_before_relax (fragS * fragP ATTRIBUTE_UNUSED,
			       segT segment_type ATTRIBUTE_UNUSED)
{
#if 0

    sbss_segment = bfd_get_section_by_name (stdoutput, ".sbss");
  sbss2_segment = bfd_get_section_by_name (stdoutput, ".sbss2");
  sdata_segment = bfd_get_section_by_name (stdoutput, ".sdata");
  sdata2_segment = bfd_get_section_by_name (stdoutput, ".sdata2");

  printf("Estimate size before relax\n");

  switch (fragP->fr_subtype)
    {
    case INST_PC_OFFSET:
      /* Used to be a PC-relative branch.  */
      if (!fragP->fr_symbol)
        {
          /* We know the abs value: Should never happen.  */
          as_bad (_("Absolute PC-relative value in relaxation code.  Assembler error....."));
          abort ();
        }
      else if ((S_GET_SEGMENT (fragP->fr_symbol) == segment_type))
        {
          fragP->fr_subtype = DEFINED_PC_OFFSET;
          /* Don't know now whether we need an imm instruction.  */
          fragP->fr_var = INST_WORD_SIZE;
        }
      else if (S_IS_DEFINED (fragP->fr_symbol)
	       && (((S_GET_SEGMENT (fragP->fr_symbol))->flags & SEC_CODE) == 0))
        {
          /* Cannot have a PC-relative branch to a diff segment.  */
          as_bad (_("PC relative branch to label %s which is not in the instruction space"),
		  S_GET_NAME (fragP->fr_symbol));
          fragP->fr_subtype = UNDEFINED_PC_OFFSET;
          fragP->fr_var = INST_WORD_SIZE*2;
        }
      else
	{
	  fragP->fr_subtype = UNDEFINED_PC_OFFSET;
	  fragP->fr_var = INST_WORD_SIZE*2;
	}
      break;

    case INST_NO_OFFSET:
      /* Used to be a reference to somewhere which was unknown.  */
      if (fragP->fr_symbol)
        {
	  if (fragP->fr_opcode == NULL)
	    {
              /* Used as an absolute value.  */
              fragP->fr_subtype = DEFINED_ABS_SEGMENT;
              /* Variable part does not change.  */
              fragP->fr_var = INST_WORD_SIZE*2;
            }

#if 0
	  else if (streq (fragP->fr_opcode, str_microblaze_ro_anchor))
	    {
              /* It is accessed using the small data read only anchor.  */
              if ((S_GET_SEGMENT (fragP->fr_symbol) == bfd_com_section_ptr)
		  || (S_GET_SEGMENT (fragP->fr_symbol) == sdata2_segment)
		  || (S_GET_SEGMENT (fragP->fr_symbol) == sbss2_segment)
		  || (! S_IS_DEFINED (fragP->fr_symbol)))
		{
                  fragP->fr_subtype = DEFINED_RO_SEGMENT;
                  fragP->fr_var = INST_WORD_SIZE;
                }
	      else
		{
                  /* Variable not in small data read only segment accessed
		     using small data read only anchor.  */
                  char *file = fragP->fr_file ? fragP->fr_file : _("unknown");

                  as_bad_where (file, fragP->fr_line,
                                _("Variable is accessed using small data read "
				  "only anchor, but it is not in the small data "
			          "read only section"));
                  fragP->fr_subtype = DEFINED_RO_SEGMENT;
                  fragP->fr_var = INST_WORD_SIZE;
                }
            }
	  else if (streq (fragP->fr_opcode, str_microblaze_rw_anchor))
	    {
              if ((S_GET_SEGMENT (fragP->fr_symbol) == bfd_com_section_ptr)
		  || (S_GET_SEGMENT (fragP->fr_symbol) == sdata_segment)
		  || (S_GET_SEGMENT (fragP->fr_symbol) == sbss_segment)
		  || (!S_IS_DEFINED (fragP->fr_symbol)))
	        {
                  /* It is accessed using the small data read write anchor.  */
                  fragP->fr_subtype = DEFINED_RW_SEGMENT;
                  fragP->fr_var = INST_WORD_SIZE;
                }
	      else
		{
                  char *file = fragP->fr_file ? fragP->fr_file : _("unknown");

                  as_bad_where (file, fragP->fr_line,
                                _("Variable is accessed using small data read "
				  "write anchor, but it is not in the small data "
				  "read write section"));
                  fragP->fr_subtype = DEFINED_RW_SEGMENT;
                  fragP->fr_var = INST_WORD_SIZE;
                }
            }
#endif
          else
	    {
              as_bad (_("Incorrect fr_opcode value in frag.  Internal error....."));
              abort ();
            }
	}
      else
	{
	  /* We know the abs value: Should never happen.  */
	  as_bad (_("Absolute value in relaxation code.  Assembler error....."));
	  abort ();
	}
      break;

    case UNDEFINED_PC_OFFSET:
    case LARGE_DEFINED_PC_OFFSET:
    case DEFINED_ABS_SEGMENT:
    case GOT_OFFSET:
    case PLT_OFFSET:
    case GOTOFF_OFFSET:
      fragP->fr_var = INST_WORD_SIZE * 2;
      break;
    case DEFINED_RO_SEGMENT:
    case DEFINED_RW_SEGMENT:
    case DEFINED_PC_OFFSET:
      fragP->fr_var = INST_WORD_SIZE;
      break;
    default:
      abort ();
    }

  return fragP->fr_var;
#endif
  as_fatal("md_estimate_size_before_relax called\n");
}


/* See whether we need to force a relocation into the output file.  */
int
tc_xtc_force_relocation (fixS *fixP)
{
	switch (fixP->fx_r_type)
	{
        case BFD_RELOC_XTC_IMM_12_12_8:
        case BFD_RELOC_XTC_IMM_12_8:
        case BFD_RELOC_XTC_IMM_8:
        case BFD_RELOC_XTC_IMM_12_12_12:
        case BFD_RELOC_XTC_IMM_12_12:
        case BFD_RELOC_XTC_IMM_12:
        case BFD_RELOC_XTC_IMM_12_12_8_PCREL:
        case BFD_RELOC_XTC_IMM_12_8_PCREL:
        case BFD_RELOC_XTC_IMM_8_PCREL:
            return 1;
		 default:
		 break;
	}

  return generic_force_reloc (fixP);
}

int
tc_xtc_fix_adjustable (fixS *fixP)
{
  switch (fixP->fx_r_type)
    {
      /* For the linker relaxation to work correctly, these relocs
         need to be on the symbol itself.  */
    case BFD_RELOC_16:
    case BFD_RELOC_32:

	/* plus these */
    case BFD_RELOC_XTC_IMM_12_12_8:
    case BFD_RELOC_XTC_IMM_12_8:
    case BFD_RELOC_XTC_IMM_8:

    case BFD_RELOC_XTC_IMM_12_12_12:
    case BFD_RELOC_XTC_IMM_12_12:
    case BFD_RELOC_XTC_IMM_12:

    case BFD_RELOC_XTC_IMM_12_12_8_PCREL:
    case BFD_RELOC_XTC_IMM_12_8_PCREL:
    case BFD_RELOC_XTC_IMM_8_PCREL:

        return 0;

    default:
      return 1; 
    }
}

