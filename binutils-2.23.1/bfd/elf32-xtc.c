#include "sysdep.h"
#include "bfd.h"
#include "bfdlink.h"
#include "libbfd.h"
#include "elf-bfd.h"
#include "elf/xtc.h"
#include <assert.h>

#define INST_WORD_SIZE 2

static void xtc_emit_relocation(int rel, long value, bfd_byte *dest);
static int xtc_reloc_pcrel_offset(int rel);


#if 0
static bfd_reloc_status_type
init_insn_reloc (bfd *abfd, arelent *reloc_entry, asymbol *symbol,
		 void * data, asection *input_section, bfd *output_bfd,
		 bfd_vma *prelocation, unsigned short *pinsn)
{
  bfd_vma relocation;
  reloc_howto_type *howto = reloc_entry->howto;

  if (output_bfd != (bfd *) NULL
      && (symbol->flags & BSF_SECTION_SYM) == 0
      && (! howto->partial_inplace
	  || reloc_entry->addend == 0))
    {
        reloc_entry->address += input_section->output_offset;
      return bfd_reloc_ok;
    }

  /* This works because partial_inplace is FALSE.  */
  if (output_bfd != NULL) {


      return bfd_reloc_continue;
  }

  if (reloc_entry->address > bfd_get_section_limit (abfd, input_section)) {

      return bfd_reloc_outofrange;
  }

  relocation = (symbol->value
		+ symbol->section->output_section->vma
		+ symbol->section->output_offset);
  relocation += reloc_entry->addend;
  if (howto->pc_relative)
    {
      relocation -= (input_section->output_section->vma
		     + input_section->output_offset);
      relocation -= reloc_entry->address;
    }

  *prelocation = relocation;
  *pinsn++ = bfd_get_16 (abfd, (bfd_byte *) data + reloc_entry->address);
  *pinsn++ = bfd_get_16 (abfd, (bfd_byte *) data + reloc_entry->address + 2);
  *pinsn = bfd_get_16 (abfd, (bfd_byte *) data + reloc_entry->address + 4);
  return bfd_reloc_other;
}


static bfd_reloc_status_type
xtc_elf_imm_12_12_8_reloc (bfd *abfd, arelent *reloc_entry, asymbol *symbol,
                          void * data, asection *input_section, bfd *output_bfd,
                          char **error_message ATTRIBUTE_UNUSED)
{
  bfd_vma relocation;
  unsigned short insn[3];
  bfd_reloc_status_type status;

  status = init_insn_reloc (abfd, reloc_entry, symbol, data,
			    input_section, output_bfd, &relocation, &insn[0]);
  if (status != bfd_reloc_other)
    return status;

  abort();

  insn[0] &= ~  0xfff;
  insn[0] |= (((relocation >> 2) & 0xc000) << 6) | ((relocation >> 2) & 0x3fff);
  bfd_put_16 (abfd, insn[0], (bfd_byte *) data + reloc_entry->address);

  if ((bfd_signed_vma) relocation < - 0x40000
      || (bfd_signed_vma) relocation > 0x3ffff)
    return bfd_reloc_overflow;
  else
    return bfd_reloc_ok;
}

static bfd_reloc_status_type
xtc_elf_imm_12_8_reloc (bfd *abfd, arelent *reloc_entry, asymbol *symbol,
                          void * data, asection *input_section, bfd *output_bfd,
                          char **error_message ATTRIBUTE_UNUSED)
{
  bfd_vma relocation;
  unsigned short insn[3];
  bfd_reloc_status_type status;
  abort();

  status = init_insn_reloc (abfd, reloc_entry, symbol, data,
			    input_section, output_bfd, &relocation, &insn[0]);
  if (status != bfd_reloc_other)
    return status;
  abort();

  insn[0] &= ~ (bfd_vma) 0x303fff;
  insn[0] |= (((relocation >> 2) & 0xc000) << 6) | ((relocation >> 2) & 0x3fff);
  bfd_put_16 (abfd, insn[0], (bfd_byte *) data + reloc_entry->address);

  if ((bfd_signed_vma) relocation < - 0x40000
      || (bfd_signed_vma) relocation > 0x3ffff)
    return bfd_reloc_overflow;
  else
    return bfd_reloc_ok;
}

static bfd_reloc_status_type
xtc_elf_imm_8_reloc (bfd *abfd, arelent *reloc_entry, asymbol *symbol,
                          void * data, asection *input_section, bfd *output_bfd,
                          char **error_message ATTRIBUTE_UNUSED)
{
  bfd_vma relocation;
  unsigned short insn[3];
  bfd_reloc_status_type status;
  abort();
  status = init_insn_reloc (abfd, reloc_entry, symbol, data,
			    input_section, output_bfd, &relocation, &insn[0]);
  if (status != bfd_reloc_other)
    return status;
  abort();

  insn[0] &= ~ (bfd_vma) 0x303fff;
  insn[0] |= (((relocation >> 2) & 0xc000) << 6) | ((relocation >> 2) & 0x3fff);
  bfd_put_32 (abfd, insn[0], (bfd_byte *) data + reloc_entry->address);

  if ((bfd_signed_vma) relocation < - 0x40000
      || (bfd_signed_vma) relocation > 0x3ffff)
    return bfd_reloc_overflow;
  else
    return bfd_reloc_ok;
}

#endif


static bfd_reloc_status_type
xtc_elf_ignore_reloc (bfd *abfd ATTRIBUTE_UNUSED,
                         arelent *reloc_entry,
                         asymbol *symbol ATTRIBUTE_UNUSED,
                         void *data ATTRIBUTE_UNUSED,
                         asection *input_section,
                         bfd *output_bfd,
                         char **error_message ATTRIBUTE_UNUSED)
{
  if (output_bfd != NULL)
    reloc_entry->address += input_section->output_offset;
  return bfd_reloc_ok;
}


static reloc_howto_type * xtc_elf_howto_table [(int) R_XTC_max];

static reloc_howto_type xtc_elf_howto_raw[] =
{
   /* This reloc does nothing.  */
   HOWTO (R_XTC_NONE,	/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          32,			/* Bitsize.  */
          FALSE,		/* PC_relative.  */
          0,			/* Bitpos.  */
          complain_overflow_bitfield,  /* Complain on overflow.  */
          NULL,                  /* Special Function.  */
          "R_XTC_NONE", 	/* Name.  */
          FALSE,		/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0,			/* Dest Mask.  */
          FALSE),		/* PC relative offset?  */

   /* A standard 32 bit relocation.  */
   HOWTO (R_XTC_32,     	/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          32,			/* Bitsize.  */
          FALSE,		/* PC_relative.  */
          0,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          bfd_elf_generic_reloc,/* Special Function.  */
          "R_XTC_32",   	/* Name.  */
          FALSE,		/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0xffffffff,		/* Dest Mask.  */
          FALSE), 		/* PC relative offset?  */

   /* A standard PCREL 32 bit relocation.  */
   HOWTO (R_XTC_32_PCREL,/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          32,			/* Bitsize.  */
          TRUE,			/* PC_relative.  */
          0,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          bfd_elf_generic_reloc,/* Special Function.  */
          "R_XTC_32_PCREL",   	/* Name.  */
          TRUE,			/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0xffffffff,		/* Dest Mask.  */
          TRUE),  		/* PC relative offset?  */

   HOWTO (R_XTC_32_I8,/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          8,			/* Bitsize.  */
          FALSE,		/* PC_relative.  */
          0,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          xtc_elf_ignore_reloc,/* Special Function.  */
          "R_XTC_32_I8",   	/* Name.  */
          TRUE,			/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0,		        /* Dest Mask.  */
          FALSE),  		/* PC relative offset?  */

   HOWTO (R_XTC_32_E8,/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          8,			/* Bitsize.  */
          FALSE,		/* PC_relative.  */
          0,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          xtc_elf_ignore_reloc,/* Special Function.  */
          "R_XTC_32_E8",   	/* Name.  */
          TRUE,			/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0,		        /* Dest Mask.  */
          FALSE),  		/* PC relative offset?  */

   HOWTO (R_XTC_32_E8_NR,/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          8,			/* Bitsize.  */
          FALSE,		/* PC_relative.  */
          0,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          xtc_elf_ignore_reloc,/* Special Function.  */
          "R_XTC_32_E8_NR",   	/* Name.  */
          TRUE,			/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0,		        /* Dest Mask.  */
          FALSE),  		/* PC relative offset?  */

   HOWTO (R_XTC_32_E8_I8,/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          16,			/* Bitsize.  */
          FALSE,		/* PC_relative.  */
          0,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          xtc_elf_ignore_reloc,/* Special Function.  */
          "R_XTC_32_E8_I8",   	/* Name.  */
          TRUE,			/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0,		/* Dest Mask.  */
          FALSE),  		/* PC relative offset?  */

   HOWTO (R_XTC_32_E24,/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          24,			/* Bitsize.  */
          FALSE,		/* PC_relative.  */
          0,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          xtc_elf_ignore_reloc,/* Special Function.  */
          "R_XTC_32_E24",   	/* Name.  */
          TRUE,			/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0,		        /* Dest Mask.  */
          FALSE),  		/* PC relative offset?  */

   HOWTO (R_XTC_32_E24_I8,/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          32,			/* Bitsize.  */
          FALSE,		/* PC_relative.  */
          0,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          xtc_elf_ignore_reloc,/* Special Function.  */
          "R_XTC_32_E24_I8",   	/* Name.  */
          TRUE,			/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0,		        /* Dest Mask.  */
          FALSE),  		/* PC relative offset?  */

   HOWTO (R_XTC_32_E24_E8,/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          32,			/* Bitsize.  */
          FALSE,		/* PC_relative.  */
          0,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          xtc_elf_ignore_reloc,/* Special Function.  */
          "R_XTC_32_E24_E8",   	/* Name.  */
          TRUE,			/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0,		/* Dest Mask.  */
          FALSE),  		/* PC relative offset?  */
   HOWTO (R_XTC_32_E24_E8_NR,/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          32,			/* Bitsize.  */
          FALSE,		/* PC_relative.  */
          0,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          xtc_elf_ignore_reloc,/* Special Function.  */
          "R_XTC_32_E24_E8_NR",   	/* Name.  */
          TRUE,			/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0,		/* Dest Mask.  */
          FALSE),  		/* PC relative offset?  */

























   HOWTO (R_XTC_32_I8_R,/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          8,			/* Bitsize.  */
          TRUE,		/* PC_relative.  */
          0,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          xtc_elf_ignore_reloc,/* Special Function.  */
          "R_XTC_32_I8_R",   	/* Name.  */
          TRUE,			/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0xffffffff,		/* Dest Mask.  */
          TRUE),  		/* PC relative offset?  */

   HOWTO (R_XTC_32_E8_R,/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          8,			/* Bitsize.  */
          TRUE,		/* PC_relative.  */
          0,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          xtc_elf_ignore_reloc,/* Special Function.  */
          "R_XTC_32_E8_R",   	/* Name.  */
          TRUE,			/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0xffffffff,		/* Dest Mask.  */
          TRUE), /* PC relative offset?  */
   HOWTO (R_XTC_32_E8_NR_R,/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          8,			/* Bitsize.  */
          TRUE,		/* PC_relative.  */
          0,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          xtc_elf_ignore_reloc,/* Special Function.  */
          "R_XTC_32_E8_NR_R",   	/* Name.  */
          TRUE,			/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0xffffffff,		/* Dest Mask.  */
          TRUE), /* PC relative offset?  */

   HOWTO (R_XTC_32_E8_I8_R,/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          16,			/* Bitsize.  */
          TRUE,		        /* PC_relative.  */
          4,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          xtc_elf_ignore_reloc,/* Special Function.  */
          "R_XTC_32_E8_I8_R",   	/* Name.  */
          TRUE,			/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0x0,		/* Dest Mask.  */
          TRUE),  		/* PC relative offset?  */

   HOWTO (R_XTC_32_E24_R,/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          24,			/* Bitsize.  */
          TRUE,		        /* PC_relative.  */
          4,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          xtc_elf_ignore_reloc,/* Special Function.  */
          "R_XTC_32_E24_R",   	/* Name.  */
          TRUE,			/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0x0,		/* Dest Mask.  */
          TRUE),  		/* PC relative offset?  */
   HOWTO (R_XTC_32_E24_I8_R,/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          32,			/* Bitsize.  */
          TRUE,		        /* PC_relative.  */
          4,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          xtc_elf_ignore_reloc,/* Special Function.  */
          "R_XTC_32_E24_I8_R",   	/* Name.  */
          TRUE,			/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0x0,		/* Dest Mask.  */
          TRUE),  		/* PC relative offset?  */
   HOWTO (R_XTC_32_E24_E8_R,/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          32,			/* Bitsize.  */
          TRUE,		        /* PC_relative.  */
          4,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          xtc_elf_ignore_reloc,/* Special Function.  */
          "R_XTC_32_E24_E8_R",   	/* Name.  */
          TRUE,			/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0x0,		/* Dest Mask.  */
          TRUE),  		/* PC relative offset?  */
   HOWTO (R_XTC_32_E24_E8_NR_R,/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          32,			/* Bitsize.  */
          TRUE,		        /* PC_relative.  */
          4,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          xtc_elf_ignore_reloc,/* Special Function.  */
          "R_XTC_32_E24_E8_NR_R",   	/* Name.  */
          TRUE,			/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0x0,		/* Dest Mask.  */
          TRUE)  		/* PC relative offset?  */
};

#ifndef NUM_ELEM
#define NUM_ELEM(a) (sizeof (a) / sizeof (a)[0])
#endif

static void
xtc_elf_howto_init (void)
{
  unsigned int i;

  for (i = NUM_ELEM (xtc_elf_howto_raw); i--;)
    {
      unsigned int type;

      type = xtc_elf_howto_raw[i].type;

      BFD_ASSERT (type < NUM_ELEM (xtc_elf_howto_table));

      xtc_elf_howto_table [type] = & xtc_elf_howto_raw [i];
    }
}

static reloc_howto_type *
xtc_elf_reloc_type_lookup (bfd * abfd ATTRIBUTE_UNUSED,
				  bfd_reloc_code_real_type code)
{
  enum elf_xtc_reloc_type xtc_reloc = R_XTC_NONE;

  switch (code)
    {
    case BFD_RELOC_NONE:
      xtc_reloc = R_XTC_NONE;
      break;
    case BFD_RELOC_32:
      xtc_reloc = R_XTC_32;
      break;
      /* RVA is treated the same as 32 */
    case BFD_RELOC_RVA:

      xtc_reloc = R_XTC_32;
      break;
    case BFD_RELOC_32_PCREL:

      xtc_reloc = R_XTC_32_PCREL;
      break;

    case BFD_RELOC_XTC_32:

        xtc_reloc = R_XTC_32;
        break;

    case BFD_RELOC_XTC_32_PCREL:

        xtc_reloc = R_XTC_32_PCREL;
        break;

    case BFD_RELOC_XTC_I8:
        xtc_reloc = R_XTC_32_I8;
        break;
    case BFD_RELOC_XTC_E8:
        xtc_reloc = R_XTC_32_E8;
        break;
    case BFD_RELOC_XTC_E8_NR:
        xtc_reloc = R_XTC_32_E8_NR;
        break;
    case BFD_RELOC_XTC_E8_I8:
        xtc_reloc = R_XTC_32_E8_I8;
        break;
    case BFD_RELOC_XTC_E24:
        xtc_reloc = R_XTC_32_E24;
        break;
    case BFD_RELOC_XTC_E24_I8:
        xtc_reloc = R_XTC_32_E24_I8;
        break;
    case BFD_RELOC_XTC_E24_E8:
        xtc_reloc = R_XTC_32_E24_E8;
        break;
    case BFD_RELOC_XTC_E24_E8_NR:
        xtc_reloc = R_XTC_32_E24_E8_NR;
        break;

    case BFD_RELOC_XTC_I8_PCREL:
        xtc_reloc = R_XTC_32_I8_R;
        break;
    case BFD_RELOC_XTC_E8_PCREL:
        xtc_reloc = R_XTC_32_E8_R;
        break;
    case BFD_RELOC_XTC_E8_NR_PCREL:
        xtc_reloc = R_XTC_32_E8_NR_R;
        break;
    case BFD_RELOC_XTC_E8_I8_PCREL:
        xtc_reloc = R_XTC_32_E8_I8_R;
        break;
    case BFD_RELOC_XTC_E24_PCREL:
        xtc_reloc = R_XTC_32_E24_R;
        break;
    case BFD_RELOC_XTC_E24_I8_PCREL:
        xtc_reloc = R_XTC_32_E24_I8_R;
        break;
    case BFD_RELOC_XTC_E24_E8_PCREL:
        xtc_reloc = R_XTC_32_E24_E8_R;
        break;
    case BFD_RELOC_XTC_E24_E8_NR_PCREL:
        xtc_reloc = R_XTC_32_E24_E8_NR_R;
        break;


    default:
        abort();

      return (reloc_howto_type *) NULL;
    }

  if (!xtc_elf_howto_table [R_XTC_32])
    /* Initialize howto table if needed.  */
    xtc_elf_howto_init ();

  return xtc_elf_howto_table [(int) xtc_reloc];
};

static reloc_howto_type *
xtc_elf_reloc_name_lookup (bfd *abfd ATTRIBUTE_UNUSED,
				  const char *r_name)
{
  unsigned int i;

  for (i = 0; i < NUM_ELEM (xtc_elf_howto_raw); i++)
    if (xtc_elf_howto_raw[i].name != NULL
	&& strcasecmp (xtc_elf_howto_raw[i].name, r_name) == 0)
      return &xtc_elf_howto_raw[i];

  return NULL;
}

/* Set the howto pointer for a RCE ELF reloc.  */

static void
xtc_elf_info_to_howto (bfd * abfd ATTRIBUTE_UNUSED,
			      arelent * cache_ptr,
			      Elf_Internal_Rela * dst)
{
  if (!xtc_elf_howto_table [R_XTC_32])
    /* Initialize howto table if needed.  */
    xtc_elf_howto_init ();

  BFD_ASSERT (ELF32_R_TYPE (dst->r_info) < (unsigned int) R_XTC_max);

  cache_ptr->howto = xtc_elf_howto_table [ELF32_R_TYPE (dst->r_info)];
}

struct elf32_mb_dyn_relocs
{
 // struct elf32_mb_dyn_relocs *next;

  /* The input section of the reloc.  */
  asection *sec;

  /* Total number of relocs copied for the input section.  */
  bfd_size_type count;

  /* Number of pc-relative relocs copied for the input section.  */
  bfd_size_type pc_count;
};

/* ELF linker hash entry.  */

struct elf32_mb_link_hash_entry
{
  struct elf_link_hash_entry elf;

  /* Track dynamic relocs copied for this symbol.  */
  //struct elf32_mb_dyn_relocs *dyn_relocs;

};

#define elf32_mb_hash_entry(ent) ((struct elf32_mb_link_hash_entry *)(ent))

/* ELF linker hash table.  */

struct elf32_mb_link_hash_table
{
  struct elf_link_hash_table elf;

  /* Short-cuts to get to dynamic linker sections.  */
  asection *sgot;
  asection *sgotplt;
  asection *srelgot;
  asection *splt;
  asection *srelplt;
  asection *sdynbss;
  asection *srelbss;

  /* Small local sym to section mapping cache.  */
  struct sym_cache sym_sec;
};

/* Get the ELF linker hash table from a link_info structure.  */

#define elf32_mb_hash_table(p)				\
  (elf_hash_table_id ((struct elf_link_hash_table *) ((p)->hash)) \
  == XTC_ELF_DATA ? ((struct elf32_mb_link_hash_table *) ((p)->hash)) : NULL)

/* Create an entry in a xtc ELF linker hash table.  */

static struct bfd_hash_entry *
link_hash_newfunc (struct bfd_hash_entry *entry,
		   struct bfd_hash_table *table,
		   const char *string)
{
  /* Allocate the structure if it has not already been allocated by a
     subclass.  */
  if (entry == NULL)
    {
      entry = bfd_hash_allocate (table,
				 sizeof (struct elf32_mb_link_hash_entry));
      if (entry == NULL)
	return entry;
    }

  /* Call the allocation method of the superclass.  */
  entry = _bfd_elf_link_hash_newfunc (entry, table, string);
  if (entry != NULL)
    {
      //struct elf32_mb_link_hash_entry *eh;

      //eh = (struct elf32_mb_link_hash_entry *) entry;
      //eh->dyn_relocs = NULL;
    }

  return entry;
}

/* Create a mb ELF linker hash table.  */

static struct bfd_link_hash_table *
xtc_elf_link_hash_table_create (bfd *abfd)
{
  struct elf32_mb_link_hash_table *ret;
  bfd_size_type amt = sizeof (struct elf32_mb_link_hash_table);

  ret = (struct elf32_mb_link_hash_table *) bfd_zmalloc (amt);
  if (ret == NULL)
    return NULL;

  if (!_bfd_elf_link_hash_table_init (&ret->elf, abfd, link_hash_newfunc,
				      sizeof (struct elf32_mb_link_hash_entry),
				      XTC_ELF_DATA))
    {
      free (ret);
      return NULL;
    }

  return &ret->elf.root;
}


static bfd_boolean
xtc_get_relocation_value (bfd *input_bfd, struct bfd_link_info *info,
                             asection *input_section,
                             asection **local_sections,
                             Elf_Internal_Sym *local_syms,
                             Elf_Internal_Rela *rel,
                             const char **name,
                             bfd_vma *relocation)
{
    Elf_Internal_Shdr *symtab_hdr;
    struct elf_link_hash_entry **sym_hashes;
    unsigned long r_symndx;
    asection *sec;
    struct elf_link_hash_entry *h;
    Elf_Internal_Sym *sym;
    //const char* stub_name = 0;

    symtab_hdr = &elf_tdata (input_bfd)->symtab_hdr;
    sym_hashes = elf_sym_hashes (input_bfd);

    r_symndx = ELF32_R_SYM (rel->r_info);

    /* This is a final link.  */
    h = NULL;
    sym = NULL;
    sec = NULL;
    if (r_symndx < symtab_hdr->sh_info)
    {
        sym = local_syms + r_symndx;
        sec = local_sections[r_symndx];
        *relocation = (sec->output_section->vma
                       + sec->output_offset
                       + sym->st_value);
    }
    else
    {
        bfd_boolean unresolved_reloc, warned;

        RELOC_FOR_GLOBAL_SYMBOL (info, input_bfd, input_section, rel,
                                 r_symndx, symtab_hdr, sym_hashes,
                                 h, sec, *relocation, unresolved_reloc, warned);

      //  stub_name = h->root.root.string;
    }

    if (h != NULL)
        *name = h->root.root.string;
    else
    {
        *name = (bfd_elf_string_from_elf_section
                 (input_bfd, symtab_hdr->sh_link, sym->st_name));
        if (*name == NULL || **name == '\0')
            *name = bfd_section_name (input_bfd, sec);
    }

    return TRUE;
}



#if 0

static bfd_boolean
xtc_elf_relocate_section (bfd *output_bfd,
                             struct bfd_link_info *info,
                             bfd *input_bfd,
                             asection *input_section,
                             bfd_byte *contents,
                             Elf_Internal_Rela *relocs,
                             Elf_Internal_Sym *local_syms,
                             asection **local_sections)
{
  struct elf32_mb_link_hash_table *htab;
  Elf_Internal_Shdr *symtab_hdr = &elf_tdata (input_bfd)->symtab_hdr;
  struct elf_link_hash_entry **sym_hashes = elf_sym_hashes (input_bfd);
  Elf_Internal_Rela *rel, *relend;
  /* Assume success.  */
  bfd_boolean ret = TRUE;
  asection *sreloc;
  //bfd_vma *local_got_offsets;


  if (!xtc_elf_howto_table[R_XTC_max-1])
    xtc_elf_howto_init ();

  htab = elf32_mb_hash_table (info);
  if (htab == NULL)
    return FALSE;

  //local_got_offsets = elf_local_got_offsets (input_bfd);
  (*_bfd_error_handler) ("START\n");
  sreloc = elf_section_data (input_section)->sreloc;

  rel = relocs;
  relend = relocs + input_section->reloc_count;
  for (; rel < relend; rel++)
    {
      int r_type;
      reloc_howto_type *howto;
      unsigned long r_symndx;
      bfd_vma addend = rel->r_addend;
      bfd_vma offset = rel->r_offset;
      struct elf_link_hash_entry *h;
      Elf_Internal_Sym *sym;
      asection *sec;
      //const char *sym_name;
      bfd_reloc_status_type r = bfd_reloc_ok;
      const char *errmsg = NULL;
      bfd_boolean unresolved_reloc = FALSE;

      h = NULL;
      r_type = ELF32_R_TYPE (rel->r_info);
      if (r_type < 0 || r_type >= (int) R_XTC_max)
	{
	  (*_bfd_error_handler) (_("%s: unknown relocation type %d"),
				 bfd_get_filename (input_bfd), (int) r_type);
	  bfd_set_error (bfd_error_bad_value);
	  ret = FALSE;
	  continue;
	}

      howto = xtc_elf_howto_table[r_type];

      BFD_ASSERT(NULL!=howto);

      r_symndx = ELF32_R_SYM (rel->r_info);

      if (info->relocatable)
	{
	  /* This is a relocatable link.  We don't have to change
	     anything, unless the reloc is against a section symbol,
	     in which case we have to adjust according to where the
	     section symbol winds up in the output section.  */
	  sec = NULL;
	  if (r_symndx >= symtab_hdr->sh_info)
	    /* External symbol.  */
	    continue;

	  /* Local symbol.  */
	  sym = local_syms + r_symndx;
	  //sym_name = "<local symbol>";
	  /* STT_SECTION: symbol is associated with a section.  */
	  if (ELF_ST_TYPE (sym->st_info) != STT_SECTION)
	    /* Symbol isn't associated with a section.  Nothing to do.  */
	    continue;

	  sec = local_sections[r_symndx];
	  addend += sec->output_offset + sym->st_value;
#ifndef USE_REL
	  /* This can't be done for USE_REL because it doesn't mean anything
	     and elf_link_input_bfd asserts this stays zero.  */
	  /* rel->r_addend = addend; */
#endif

#ifndef USE_REL
	  /* Addends are stored with relocs.  We're done.  */
	  continue;
#else /* USE_REL */
	  /* If partial_inplace, we need to store any additional addend
	     back in the section.  */
	  if (!howto->partial_inplace)
	    continue;
	  /* ??? Here is a nice place to call a special_function like handler.  */
	  r = _bfd_relocate_contents (howto, input_bfd, addend,
				      contents + offset);
#endif /* USE_REL */
	}
      else
	{
	  bfd_vma relocation;

	  /* This is a final link.  */
	  sym = NULL;
	  sec = NULL;
	  unresolved_reloc = FALSE;

	  if (r_symndx < symtab_hdr->sh_info)
	    {
	      /* Local symbol.  */
	      sym = local_syms + r_symndx;
	      sec = local_sections[r_symndx];
	      if (sec == 0)
		continue;
	    //  sym_name = "<local symbol>";
	      relocation = _bfd_elf_rela_local_sym (output_bfd, sym, &sec, rel);
	      /* r_addend may have changed if the reference section was
		 a merge section.  */
	      addend = rel->r_addend;
	    }
	  else
	    {
	      /* External symbol.  */
	      bfd_boolean warned ATTRIBUTE_UNUSED;

	      RELOC_FOR_GLOBAL_SYMBOL (info, input_bfd, input_section, rel,
				       r_symndx, symtab_hdr, sym_hashes,
				       h, sec, relocation,
				       unresolved_reloc, warned);
	      //sym_name = h->root.root.string;
	    }

	  /* Sanity check the address.  */
	  if (offset > bfd_get_section_limit (input_bfd, input_section))
	    {
	      r = bfd_reloc_outofrange;
	      goto check_reloc;
	    }

	  switch ((int) r_type)
	    {
	    case (int) R_XTC_32_IMM_12_12_8_PCREL:
            case (int) R_XTC_32:
	      {
		/* r_symndx will be STN_UNDEF (zero) only for relocs against symbols
		   from removed linkonce sections, or sections discarded by
		   a linker script.  */
		if (r_symndx == STN_UNDEF || (input_section->flags & SEC_ALLOC) == 0)
                {
		    relocation += addend;
                    if (r_type == R_XTC_32)
		      bfd_put_32 (input_bfd, relocation, contents + offset);
		    else
                    {
                                                      /*
			if (r_type == R_XTC_32_PCREL)
			  relocation -= (input_section->output_section->vma
					 + input_section->output_offset
                                         + offset );*/

                        (*_bfd_error_handler) ("Relocating PCREL\n");

                        unsigned inst = bfd_get_16( input_bfd, contents + offset);
                        inst |= (relocation >> (8+12))&0xFFF;
                        bfd_put_16 (input_bfd, inst, contents + offset);

                        inst = bfd_get_16( input_bfd, contents + offset + 2);
                        inst |= (relocation >> 8) & 0xFFF;
                        bfd_put_16 (input_bfd, inst, contents + offset + 2);

                        inst = bfd_get_16( input_bfd, contents + offset + 4);

                        inst |= (relocation & 0xFF)<<4;

                        bfd_put_16 (input_bfd, inst,
				    contents + offset + 4);
                      }
                    (*_bfd_error_handler) ("Reloction done\n");
		    break;
		  }

		if ((info->shared
		     && (h == NULL
			 || ELF_ST_VISIBILITY (h->other) == STV_DEFAULT
			 || h->root.type != bfd_link_hash_undefweak)
		     && (!howto->pc_relative
			 || (h != NULL
			     && h->dynindx != -1
			     && (!info->symbolic
				 || !h->def_regular))))
		    || (!info->shared
			&& h != NULL
			&& h->dynindx != -1
			&& !h->non_got_ref
			&& ((h->def_dynamic
			     && !h->def_regular)
			    || h->root.type == bfd_link_hash_undefweak
			    || h->root.type == bfd_link_hash_undefined)))
		  {
		    Elf_Internal_Rela outrel;
		    bfd_byte *loc;
		    bfd_boolean skip;

		    /* When generating a shared object, these relocations
		       are copied into the output file to be resolved at run
		       time.  */

		    BFD_ASSERT (sreloc != NULL);

		    skip = FALSE;

		    outrel.r_offset =
		      _bfd_elf_section_offset (output_bfd, info, input_section,
					       rel->r_offset);
		    if (outrel.r_offset == (bfd_vma) -1)
		      skip = TRUE;
		    else if (outrel.r_offset == (bfd_vma) -2)
		      skip = TRUE;
		    outrel.r_offset += (input_section->output_section->vma
					+ input_section->output_offset);

		    if (skip)
		      memset (&outrel, 0, sizeof outrel);
		    /* h->dynindx may be -1 if the symbol was marked to
		       become local.  */
		    else if (h != NULL
			     && ((! info->symbolic && h->dynindx != -1)
				 || !h->def_regular))
		      {
			BFD_ASSERT (h->dynindx != -1);
			outrel.r_info = ELF32_R_INFO (h->dynindx, r_type);
			outrel.r_addend = addend;
		      }
		    else
                    {
#if 0
			if (r_type == R_XTC_32)
			  {
			    outrel.r_info = ELF32_R_INFO (0, R_XTC_REL);
			    outrel.r_addend = relocation + addend;
			  }
			else
			  {
			    BFD_FAIL ();
			    (*_bfd_error_handler)
			      (_("%B: probably compiled without -fPIC?"),
			       input_bfd);
			    bfd_set_error (bfd_error_bad_value);
			    return FALSE;
			  }
#endif
                        abort();
                    }

		    loc = sreloc->contents;
		    loc += sreloc->reloc_count++ * sizeof (Elf32_External_Rela);
		    bfd_elf32_swap_reloca_out (output_bfd, &outrel, loc);
		    break;
		  }
                else
                {
//                    (*_bfd_error_handler) ("Relocating here\n");
		    relocation += addend;
                    if (r_type == R_XTC_32) {
                        bfd_put_32 (input_bfd, relocation, contents + offset);
                        abort();
                    }
		    else
		      {
                          if (r_type == R_XTC_32_PCREL) {
                              relocation -= (input_section->output_section->vma
                                             + input_section->output_offset
                                             + offset + INST_WORD_SIZE*3);
                          }


                        unsigned inst = bfd_get_16( input_bfd, contents + offset);
                        inst |= (relocation >> (8+12))&0xFFF;
                        bfd_put_16 (input_bfd, inst, contents + offset);

                        inst = bfd_get_16( input_bfd, contents + offset + 2);
                        inst |= (relocation >> 8) & 0xFFF;
                        bfd_put_16 (input_bfd, inst, contents + offset + 2);

                        inst = bfd_get_16( input_bfd, contents + offset + 4);

                        inst |= (relocation & 0xFF)<<4;

                        bfd_put_16 (input_bfd, inst,
				    contents + offset + 4);
		      }
		    break;
		  }
	      }

	    default :
	      r = _bfd_final_link_relocate (howto, input_bfd, input_section,
					    contents, offset,
					    relocation, addend);
	      break;
	    }
	}

    check_reloc:

      if (r != bfd_reloc_ok)
	{
	  /* FIXME: This should be generic enough to go in a utility.  */
	  const char *name;

	  if (h != NULL)
	    name = h->root.root.string;
	  else
	    {
	      name = (bfd_elf_string_from_elf_section
		      (input_bfd, symtab_hdr->sh_link, sym->st_name));
	      if (name == NULL || *name == '\0')
		name = bfd_section_name (input_bfd, sec);
	    }

	  if (errmsg != NULL)
	    goto common_error;

	  switch (r)
	    {
	    case bfd_reloc_overflow:
	      if (!((*info->callbacks->reloc_overflow)
		    (info, (h ? &h->root : NULL), name, howto->name,
		     (bfd_vma) 0, input_bfd, input_section, offset)))
		return FALSE;
	      break;

	    case bfd_reloc_undefined:
	      if (!((*info->callbacks->undefined_symbol)
		    (info, name, input_bfd, input_section, offset, TRUE)))
	        return FALSE;
	      break;

	    case bfd_reloc_outofrange:
	      errmsg = _("internal error: out of range error");
	      goto common_error;

	    case bfd_reloc_notsupported:
	      errmsg = _("internal error: unsupported relocation error");
	      goto common_error;

	    case bfd_reloc_dangerous:
	      errmsg = _("internal error: dangerous error");
	      goto common_error;

	    default:
	      errmsg = _("internal error: unknown error");
	      /* Fall through.  */
	    common_error:
	      if (!((*info->callbacks->warning)
		    (info, errmsg, name, input_bfd, input_section, offset)))
	        return FALSE;
	      break;
	    }
	}
    }

  return ret;
}


#endif
#if 0

static int xtc_bytes_12_12_8(bfd_vma value)
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

static int xtc_bytes_12_12_12(bfd_vma value)
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

static void xtc_emit_imm_12_12(bfd *abfd, bfd_byte *address, bfd_vma value)
{
    unsigned long inst = bfd_get_16(abfd, address);
    inst &= ~0x0FFF;
    inst |= (value>>12)&0x0FFF;
    bfd_put_16 (abfd, inst, address);
    inst = bfd_get_16(abfd, address + INST_WORD_SIZE);
    inst &= ~0x0FFF;
    inst |= (value)&0x0FFF;
    bfd_put_16 (abfd, inst, address + INST_WORD_SIZE);
}

static void xtc_emit_imm_12_12_12(bfd *abfd, bfd_byte *address, bfd_vma value)
{
    unsigned long inst = bfd_get_16(abfd, address);
    inst &= ~0x0FFF;
    inst |= (value>>24)&0xFFF;
    bfd_put_16 (abfd, inst, address);
    inst = bfd_get_16(abfd, address + INST_WORD_SIZE);
    inst &= ~0x0FFF;
    inst |= (value>>12)&0xFFF;
    bfd_put_16 (abfd, inst, address + INST_WORD_SIZE);
    inst = bfd_get_16(abfd, address + INST_WORD_SIZE*2);
    inst &= ~0x0FFF;
    inst |= (value)&0x0FFF;
    bfd_put_16 (abfd, inst, address + INST_WORD_SIZE*2);
}

static void xtc_emit_imm_12_8(bfd *abfd, bfd_byte *address, bfd_vma value)
{
    unsigned long inst = bfd_get_16(abfd, address);
    inst &= ~0x0FFF;
    inst |= (value>>8)&0xFFF;
    bfd_put_16 (abfd, inst, address);
    inst = bfd_get_16(abfd, address + INST_WORD_SIZE);
    inst &= ~0x0FF0;
    inst |= (value<<4)&0x0FF0;
    bfd_put_16 (abfd, inst, address + INST_WORD_SIZE);
}

static void xtc_emit_imm_12_12_8(bfd *abfd, bfd_byte *address, bfd_vma value)
{
    unsigned long inst = bfd_get_16(abfd, address);
    inst &= ~0x0FFF;
    inst |= (value>>20)&0xFFF;
    bfd_put_16 (abfd, inst, address);
    inst = bfd_get_16(abfd, address + INST_WORD_SIZE);
    inst &= ~0x0FFF;
    inst |= (value>>8)&0xFFF;
    bfd_put_16 (abfd, inst, address + INST_WORD_SIZE);
    inst = bfd_get_16(abfd, address + INST_WORD_SIZE*2);
    inst &= ~0x0FF0;
    inst |= (value<<4)&0x0FF0;
    bfd_put_16 (abfd, inst, address + INST_WORD_SIZE*2);
}

static void xtc_emit_imm_8(bfd *abfd, bfd_byte *address, bfd_vma value)
{
    unsigned long inst = bfd_get_16(abfd, address);

    inst &= ~0x0FF0;
    inst |= (value<<4)&0x0FF0;
    bfd_put_16 (abfd, inst, address);
}

static void xtc_emit_imm_12(bfd *abfd, bfd_byte *address, bfd_vma value)
{
    unsigned long inst = bfd_get_16(abfd, address);
    inst &= ~0x0FFF;
    inst |= (value)&0x0FFF;
    bfd_put_16 (abfd, inst, address);
}

static void xtc_emit_imm_121212(bfd *abfd, bfd_byte *address, bfd_vma value, int size)
{
    switch(size) {
    case 3:
        xtc_emit_imm_12_12_12(abfd,address,value);
        break;
    case 2:
        xtc_emit_imm_12_12(abfd,address,value);
        break;
    case 1:
        xtc_emit_imm_12(abfd,address,value);
        break;
    default:
        abort();
    }
}

static void xtc_emit_imm_12128(bfd *abfd, bfd_byte *address, bfd_vma value, int size)
{
    switch(size) {
    case 3:
        xtc_emit_imm_12_12_8(abfd,address,value);
        break;
    case 2:
        xtc_emit_imm_12_8(abfd,address,value);
        break;
    case 1:
        xtc_emit_imm_8(abfd,address,value);
        break;
    default:
        abort();
    }
}
#endif

static bfd_boolean
xtc_elf_relocate_section (bfd *output_bfd ATTRIBUTE_UNUSED,
                             struct bfd_link_info *info,
                             bfd *input_bfd, asection *input_section,
                             bfd_byte *contents, Elf_Internal_Rela *relocs,
                             Elf_Internal_Sym *local_syms,
                             asection **local_sections)
{
  Elf_Internal_Shdr *symtab_hdr;
  //struct elf_link_hash_entry **sym_hashes;
  Elf_Internal_Rela *rel, *relend;
  const char *name = NULL;
  //const struct elf_backend_data * const ebd = get_elf_backend_data (input_bfd);

  symtab_hdr = &elf_tdata (input_bfd)->symtab_hdr;
//  sym_hashes = elf_sym_hashes (input_bfd);

  if (!xtc_elf_howto_table[R_XTC_max-1])
    xtc_elf_howto_init ();

  /* Get memory bank parameters.  */

  rel = relocs;
  relend = relocs + input_section->reloc_count;
  for (; rel < relend; rel++)
    {
      int r_type;
      //arelent arel;
      reloc_howto_type *howto;
      unsigned long r_symndx;
      bfd_vma phys_addr, reserved;
      Elf_Internal_Sym *sym;
      asection *sec;
      bfd_vma relocation=0;
      bfd_reloc_status_type r = bfd_reloc_undefined;
      int pcrel;

      r_symndx = ELF32_R_SYM (rel->r_info);
      r_type = ELF32_R_TYPE (rel->r_info);


      if (info->relocatable)
	{
	  /* This is a relocatable link.  We don't have to change
	     anything, unless the reloc is against a section symbol,
	     in which case we have to adjust according to where the
	     section symbol winds up in the output section.  */
	  if (r_symndx < symtab_hdr->sh_info)
	    {
	      sym = local_syms + r_symndx;
	      if (ELF_ST_TYPE (sym->st_info) == STT_SECTION)
		{
		  sec = local_sections[r_symndx];
		  rel->r_addend += sec->output_offset + sym->st_value;
		}
	    }

	  continue;
	}
      //(*ebd->elf_info_to_howto_rel) (input_bfd, &arel, rel);
      //howto = arel.howto;
      howto = xtc_elf_howto_table[ELF32_R_TYPE (rel->r_info)];

      BFD_ASSERT(NULL!=howto);

      xtc_get_relocation_value (input_bfd, info, input_section,
                                   local_sections, local_syms,
                                   rel, &name, &relocation);
      pcrel=0;
      //fullim=0;
      switch (r_type)
      {
      case R_XTC_32_I8_R:
      case R_XTC_32_E8_R:
      case R_XTC_32_E8_I8_R:
      case R_XTC_32_E24_R:
      case R_XTC_32_E24_I8_R:
      case R_XTC_32_E24_E8_R:
          pcrel=1;

      case R_XTC_32_I8:
      case R_XTC_32_E8:
      case R_XTC_32_E8_I8:
      case R_XTC_32_E24:
      case R_XTC_32_E24_I8:
      case R_XTC_32_E24_E8:

          if (pcrel) {
              reserved = xtc_reloc_pcrel_offset(r_type);
              phys_addr = relocation + rel->r_addend;
              phys_addr -= (input_section->output_section->vma
                            + input_section->output_offset);

              phys_addr -= rel->r_offset;
              phys_addr += rel->r_addend;
          } else {
              reserved = 0;
              phys_addr = relocation + rel->r_addend;
          }

          //printf("Relocating symbol '%s', address 0x%lx, at offset 0x%lx\n", name, phys_addr, rel->r_offset);
          xtc_emit_relocation(r_type, phys_addr-reserved, (bfd_byte*) contents + rel->r_offset);


          r_type = R_XTC_NONE;
          r = bfd_reloc_ok;

      break;

        case R_XTC_NONE:
          r = bfd_reloc_ok;
          break;
      case R_XTC_32:
          /* Waht... */
#if 0
          bfd_put_32( input_bfd,
                     contents + rel->r_offset,
                     relocation + rel->r_addend);
#endif
          r = bfd_reloc_ok;
          break;

      default:
          fprintf(stderr,"Cannot handle relocation type %d\n", r_type);
          return FALSE;

      break;
        }
        if (r_type!=R_XTC_NONE)
        {
            /* those that we did not handle ourselves */
            r = _bfd_final_link_relocate (howto, input_bfd, input_section,
                                          contents, rel->r_offset,
                                          relocation, rel->r_addend);
        }


      if (r != bfd_reloc_ok)
	{
	  const char * msg = (const char *) 0;

	  switch (r)
	    {
	    case bfd_reloc_overflow:
	      if (!((*info->callbacks->reloc_overflow)
		    (info, NULL, name, howto->name,
		     (bfd_vma) 0, input_bfd, input_section, rel->r_offset)))
		return FALSE;
	      break;

	    case bfd_reloc_undefined:
	      if (!((*info->callbacks->undefined_symbol)
		    (info, name, input_bfd, input_section, rel->r_offset, TRUE)))
	        return FALSE;
	      break;

            case bfd_reloc_outofrange:
	      msg = _ ("internal error: out of range error");
	      goto common_error;

	    case bfd_reloc_notsupported:
	      msg = _ ("internal error: unsupported relocation error");
	      goto common_error;

	    case bfd_reloc_dangerous:
	      msg = _ ("internal error: dangerous error");
	      goto common_error;

	    default:
	      msg = _ ("internal error: unknown error");
	      /* fall through */

	    common_error:
                if (!((*info->callbacks->warning)
                      (info, msg, name, input_bfd, input_section, rel->r_offset)))
                    return FALSE;
                break;
	    }
	}
    }

  return TRUE;
}









/* Look through the relocs for a section during the first phase.  */

static bfd_boolean
xtc_elf_check_relocs (bfd * abfd,
                         struct bfd_link_info * info,
                         asection * sec,
                         const Elf_Internal_Rela * relocs)
{
    Elf_Internal_Shdr *           symtab_hdr;
    struct elf_link_hash_entry ** sym_hashes;
    struct elf_link_hash_entry ** sym_hashes_end;
    const Elf_Internal_Rela *     rel;
    const Elf_Internal_Rela *     rel_end;
    struct elf32_mb_link_hash_table *htab;
    asection *sreloc = NULL;



    if (info->relocatable)
        return TRUE;

    htab = elf32_mb_hash_table (info);
    if (htab == NULL)
        return FALSE;

    symtab_hdr = & elf_tdata (abfd)->symtab_hdr;
    sym_hashes = elf_sym_hashes (abfd);
    sym_hashes_end = sym_hashes + symtab_hdr->sh_size / sizeof (Elf32_External_Sym);
    if (!elf_bad_symtab (abfd))
        sym_hashes_end -= symtab_hdr->sh_info;

    rel_end = relocs + sec->reloc_count;

    for (rel = relocs; rel < rel_end; rel++)
    {
        unsigned int r_type;
        struct elf_link_hash_entry * h;
        unsigned long r_symndx;

        r_symndx = ELF32_R_SYM (rel->r_info);
        r_type = ELF32_R_TYPE (rel->r_info);

        if (r_symndx < symtab_hdr->sh_info)
            h = NULL;
        else
            h = sym_hashes [r_symndx - symtab_hdr->sh_info];

        switch (r_type)
        {
#if 0
            /* This relocation describes the C++ object vtable hierarchy.
             Reconstruct it for later use during GC.  */
        case R_XTC_GNU_VTINHERIT:
            if (!bfd_elf_gc_record_vtinherit (abfd, sec, h, rel->r_offset))
                return FALSE;
            break;

            /* This relocation describes which C++ vtable entries are actually
             used.  Record for later use during GC.  */
        case R_XTC_GNU_VTENTRY:
            if (!bfd_elf_gc_record_vtentry (abfd, sec, h, rel->r_addend))
                return FALSE;
            break;

            /* This relocation requires .plt entry.  */
        case R_XTC_PLT_64:
            if (h != NULL)
            {
                h->needs_plt = 1;
                h->plt.refcount += 1;
            }
            break;

            /* This relocation requires .got entry.  */
        case R_XTC_GOT_64:
            if (htab->sgot == NULL)
            {
                if (htab->elf.dynobj == NULL)
                    htab->elf.dynobj = abfd;
                if (!create_got_section (htab->elf.dynobj, info))
                    return FALSE;
            }
            if (h != NULL)
            {
                h->got.refcount += 1;
            }
            else
            {
                bfd_signed_vma *local_got_refcounts;

                /* This is a global offset table entry for a local symbol.  */
                local_got_refcounts = elf_local_got_refcounts (abfd);
                if (local_got_refcounts == NULL)
                {
                    bfd_size_type size;

                    size = symtab_hdr->sh_info;
                    size *= sizeof (bfd_signed_vma);
                    local_got_refcounts = bfd_zalloc (abfd, size);
                    if (local_got_refcounts == NULL)
                        return FALSE;
                    elf_local_got_refcounts (abfd) = local_got_refcounts;
                }
                local_got_refcounts[r_symndx] += 1;
            }
            break;
#endif

        case R_XTC_32:
        case R_XTC_32_PCREL:
            {
                if (h != NULL && !info->shared)
                {
                    /* we may need a copy reloc.  */
                    h->non_got_ref = 1;

                    /* we may also need a .plt entry.  */
                    h->plt.refcount += 1;
                    if (ELF32_R_TYPE (rel->r_info) != R_XTC_32_PCREL)
                        h->pointer_equality_needed = 1;
                }


                /* If we are creating a shared library, and this is a reloc
                 against a global symbol, or a non PC relative reloc
                 against a local symbol, then we need to copy the reloc
                 into the shared library.  However, if we are linking with
                 -Bsymbolic, we do not need to copy a reloc against a
                 global symbol which is defined in an object we are
                 including in the link (i.e., DEF_REGULAR is set).  At
                 this point we have not seen all the input files, so it is
                 possible that DEF_REGULAR is not set now but will be set
                 later (it is never cleared).  In case of a weak definition,
                 DEF_REGULAR may be cleared later by a strong definition in
                 a shared library.  We account for that possibility below by
                 storing information in the relocs_copied field of the hash
                 table entry.  A similar situation occurs when creating
                 shared libraries and symbol visibility changes render the
                 symbol local.

                 If on the other hand, we are creating an executable, we
                 may need to keep relocations for symbols satisfied by a
                 dynamic library if we manage to avoid copy relocs for the
                 symbol.  */

                if ((info->shared
                     && (sec->flags & SEC_ALLOC) != 0
                     && (r_type != R_XTC_32_PCREL
                         || (h != NULL
                             && (! info->symbolic
                                 || h->root.type == bfd_link_hash_defweak
                                 || !h->def_regular))))
                    || (!info->shared
                        && (sec->flags & SEC_ALLOC) != 0
                        && h != NULL
                        && (h->root.type == bfd_link_hash_defweak
                            || !h->def_regular)))
                {
                    (*_bfd_error_handler)("Cannot handle relocation for symbol");
                    abort();
                    //struct elf32_mb_dyn_relocs *p;
                    //struct elf32_mb_dyn_relocs **head;

                    /* When creating a shared object, we must copy these
                     relocs into the output file.  We create a reloc
                     section in dynobj and make room for the reloc.  */

                    if (sreloc == NULL)
                    {
                        const char *name;
                        bfd *dynobj;
                        unsigned int strndx = elf_elfheader (abfd)->e_shstrndx;
                        unsigned int shnam = _bfd_elf_single_rel_hdr (sec)->sh_name;

                        name = bfd_elf_string_from_elf_section (abfd, strndx, shnam);
                        if (name == NULL)
                            return FALSE;

                        if (strncmp (name, ".rela", 5) != 0
                            || strcmp (bfd_get_section_name (abfd, sec),
                                       name + 5) != 0)
                        {
                            (*_bfd_error_handler)
                                (_("%B: bad relocation section name `%s\'"),
                                 abfd, name);
                        }

                        if (htab->elf.dynobj == NULL)
                            htab->elf.dynobj = abfd;
                        dynobj = htab->elf.dynobj;

                        sreloc = bfd_get_linker_section (dynobj, name);
                        if (sreloc == NULL)
                        {
                            flagword flags;

                            flags = (SEC_HAS_CONTENTS | SEC_READONLY
                                     | SEC_IN_MEMORY | SEC_LINKER_CREATED);
                            if ((sec->flags & SEC_ALLOC) != 0)
                                flags |= SEC_ALLOC | SEC_LOAD;
                            sreloc = bfd_make_section_anyway_with_flags (dynobj,
                                                                         name,
                                                                         flags);
                            if (sreloc == NULL
                                || ! bfd_set_section_alignment (dynobj, sreloc, 2))
                                return FALSE;
                        }
                        elf_section_data (sec)->sreloc = sreloc;
                    }
#if 0
                    /* If this is a global symbol, we count the number of
                     relocations we need for this symbol.  */
                    if (h != NULL)
                        head = &((struct elf32_mb_link_hash_entry *) h)->dyn_relocs;
                    else
                    {
                        /* Track dynamic relocs needed for local syms too.
                         We really need local syms available to do this
                         easily.  Oh well.  */

                        asection *s;
                        Elf_Internal_Sym *isym;
                        void *vpp;

                        isym = bfd_sym_from_r_symndx (&htab->sym_sec,
                                                      abfd, r_symndx);
                        if (isym == NULL)
                            return FALSE;

                        s = bfd_section_from_elf_index (abfd, isym->st_shndx);
                        if (s == NULL)
                            return FALSE;

                        vpp = &elf_section_data (s)->local_dynrel;
                        head = (struct elf32_mb_dyn_relocs **) vpp;
                    }

                    p = *head;
                    if (p == NULL || p->sec != sec)
                    {
                        bfd_size_type amt = sizeof *p;
                        p = ((struct elf32_mb_dyn_relocs *)
                             bfd_alloc (htab->elf.dynobj, amt));
                        if (p == NULL)
                            return FALSE;
                        p->next = *head;
                        *head = p;
                        p->sec = sec;
                        p->count = 0;
                        p->pc_count = 0;
                    }
                    p->count += 1;
                    if (r_type == R_XTC_32_PCREL)
                        p->pc_count += 1;
#endif
                }
            }
            break;
        default:
            //  abort();
            break;
        }
    }

    return TRUE;
}



/* Calculate fixup value for reference.  */
#if 0
static int
calc_fixup (bfd_vma addr, asection *sec)
{
  int i, fixup = 0;

  if (sec == NULL || sec->relax == NULL)
    return 0;

  /* Look for addr in relax table, total fixup value.  */
  for (i = 0; i < sec->relax_count; i++)
  {
      if (addr <= sec->relax[i].addr)
        break;
      fixup -= sec->relax[i].size;
    }

  return fixup;
}
#endif

static void
xtc_elf_relax_delete_bytes (bfd *abfd, asection *sec,
                               bfd_vma addr, int count)
{
  Elf_Internal_Shdr *symtab_hdr;
  unsigned int sec_shndx;
  bfd_byte *contents;
  Elf_Internal_Rela *irel, *irelend;
  bfd_vma toaddr;
  Elf_Internal_Sym *isymbuf, *isym, *isymend;
  struct elf_link_hash_entry **sym_hashes;
  struct elf_link_hash_entry **end_hashes;
  unsigned int symcount;

  symtab_hdr = &elf_tdata (abfd)->symtab_hdr;
  isymbuf = (Elf_Internal_Sym *) symtab_hdr->contents;
  symcount =  symtab_hdr->sh_size / sizeof (Elf32_External_Sym);

  if (isymbuf == NULL)
      isymbuf = bfd_elf_get_elf_syms (abfd, symtab_hdr, symcount,
                                      0, NULL, NULL, NULL);
  BFD_ASSERT (isymbuf != NULL);


  sec_shndx = _bfd_elf_section_from_bfd_section (abfd, sec);

  contents = elf_section_data (sec)->this_hdr.contents;

  toaddr = sec->size;

  irel = elf_section_data (sec)->relocs;
  irelend = irel + sec->reloc_count;

  /* Actually delete the bytes.  */
  memmove (contents + addr, contents + addr + count,
	   (size_t) (toaddr - addr - count));

  sec->size -= count;

  /* Adjust all the relocs.  */
  for (irel = elf_section_data (sec)->relocs; irel < irelend; irel++)
    {
      /* Get the new reloc address.  */
      if ((irel->r_offset > addr
	   && irel->r_offset < toaddr))
	irel->r_offset -= count;

    }

  /* Adjust the local symbols defined in this section.  */
  isymend = isymbuf + symtab_hdr->sh_info;
  for (isym = isymbuf; isym < isymend; isym++)
    {
      if (isym->st_shndx == sec_shndx
	  && isym->st_value > addr
          && isym->st_value <= toaddr) {
#if 0
          char *name = (bfd_elf_string_from_elf_section
                        (abfd, symtab_hdr->sh_link, isym->st_name));
	      
#endif
          isym->st_value -= count;
      }
    }

  /* Now adjust the global symbols defined in this section.  */
  symcount = (symtab_hdr->sh_size / sizeof (Elf32_External_Sym)
	      - symtab_hdr->sh_info);
  sym_hashes = elf_sym_hashes (abfd);
  end_hashes = sym_hashes + symcount;
  for (; sym_hashes < end_hashes; sym_hashes++)
    {
      struct elf_link_hash_entry *sym_hash = *sym_hashes;
      if ((sym_hash->root.type == bfd_link_hash_defined
	   || sym_hash->root.type == bfd_link_hash_defweak)
	  && sym_hash->root.u.def.section == sec
	  && sym_hash->root.u.def.value > addr
	  && sym_hash->root.u.def.value <= toaddr)
	{
	  sym_hash->root.u.def.value -= count;
	}
    }
}

static bfd_boolean xtc_reloc_pcrel(int rel)
{
    return (rel == (int) R_XTC_32_E8_R)
        || (rel == (int) R_XTC_32_I8_R)
        || (rel == (int) R_XTC_32_E8_I8_R)
        || (rel == (int) R_XTC_32_E24_R)
        || (rel == (int) R_XTC_32_E24_I8_R)
        || (rel == (int) R_XTC_32_E24_E8_R);
}

static int xtc_reloc_pcrel_offset(int rel)
{
    int offset=0;
    switch (rel) {
    case R_XTC_32_E8_R:
        offset = 2; break;
    case R_XTC_32_I8_R:
        offset = 2; break;
    case R_XTC_32_E8_I8_R:
        offset = 4; break;
    case R_XTC_32_E24_R:
        offset = 4; break;
    case R_XTC_32_E24_I8_R:
        offset = 6; break;
    case R_XTC_32_E24_E8_R:
        offset = 6; break;
    default:
        abort();
    }
    return offset;
}

static bfd_boolean xtc_fits_imm(long imm, int bitsize)
{
    if (bitsize==0) {
        return imm==0;
    }
    long max = 1<<(bitsize-1);
    if (imm<0) {
        imm=-1 - imm;
    }
    return imm<max;
}

static void xtc_relax_e24_i8_to_e8_i8(unsigned char *location, long *value)
{
    // Move I8 backwards. It's a 4-5, move to 2-3. The
    // upper 2 bytes will be removed later on.
#if 0
    printf("E24I8->E8I8: %02x%02x %02x%02x %02x%02x to ",
           location[0],
           location[1],
           location[2],
           location[3],
           location[4],
           location[5]);
#endif
    unsigned char savecond = location[2];

    location[2] = location[4] |0x80; // Signal extended
    location[3] = location[5];

    // Move extension forward. modify for IMM
    location[4] = (savecond&0xf) | 0x40;
    location[5] = 0;
#if 0
    printf("%02x%02x %02x%02x\n",
           location[2],
           location[3],
           location[4],
           location[5]);
#endif
    if (value) {
        *value -= 4;
    }

}

static void xtc_relax_e24_to_e8( unsigned char *location ATTRIBUTE_UNUSED , long *value ATTRIBUTE_UNUSED)
{
    // xtc_relax_e24_i8_to_e8_i8(location);
    abort();
}

static void xtc_relax_e8_i8_to_i8(unsigned  char *location, long *value)
{
    // Move i8 forward
#if 0
    printf("E8I8->I8: %02x%02x %02x%02x to ",
           location[0],
           location[1],
           location[2],
           location[3]);
#endif
    location[2] = location[0] & 0x7f; // Remove extension
    location[3] = location[1];
#if 0
    printf("%02x%02x\n",
           location[2],
           location[3]);
#endif
    if (value) {
        *value -= 2;
    }
}
static void xtc_relax_e8_to_none(unsigned  char *location, long *value ATTRIBUTE_UNUSED)
{
#if 0
    printf("E8-> -- %02x%02x \n",
           location[0],
           location[1]);
#endif
    *location++=0xde;
    *location++=0xad;
}

static unsigned long xtc_get16(const bfd_byte*src)
{
    return src[1] + (((unsigned long)src[0])<<8);
}

static unsigned long xtc_get32(const bfd_byte*src)
{
    unsigned long v = xtc_get16(src)<<16;
    v |= xtc_get16(src+2);
    return v;
}

static void xtc_put16(unsigned long value, bfd_byte*dest)
{
    dest[0] = value >> 8;
    dest[1] = value;
}

static bfd_byte *xtc_emit_e24(bfd_byte *dest, long value)
{
    //unsigned long inst = 0x80006000;
    unsigned long inst = xtc_get32(dest);
    //printf("Emit E24, val %08lx\n", value);
    // Lower 15-bits of value go into the opcode itself.
    inst |= (value & 0x7fff)<<16;
    value>>=15;

    // Next 8-bits are placed in the other
    inst |= (value&0xff);
    value>>=8;
    inst |= ((value&1)<<12);

    *dest++=inst>>24;
    *dest++=inst>>16;
    *dest++=inst>>8;
    *dest++=inst;
    return dest;
}

static void xtc_emit_relocation(int rel, long value, bfd_byte *dest)
{

    switch (rel) {
    case R_XTC_32_E24_E8_R:
    case R_XTC_32_E24_E8:

        dest = xtc_emit_e24(dest,value>>8);

        xtc_put16( (xtc_get16(dest+2) & 0xFF00) | ((value)&0xff), dest+2 );

        break;

    case R_XTC_32_E24_I8_R:
    case R_XTC_32_E24_I8:
        // First, emit E24
        dest = xtc_emit_e24(dest,value>>8);
        xtc_put16( (xtc_get16(dest) & 0xF00F) | ((value<<4)&0xff0), dest);
        break;

    case R_XTC_32_E24_R:
    case R_XTC_32_E24:
        //        abort();
        /* Assert that it fits */

        BFD_ASSERT(xtc_fits_imm(value,24));
        dest = xtc_emit_e24(dest,value);

        break;

    case R_XTC_32_E8_R:
    case R_XTC_32_E8:
        dest+=2;
        // Apply extension
        xtc_put16( (xtc_get16(dest) & 0xFF00) | ((value)&0xff), dest);

        //abort();
        break;

    case R_XTC_32_E8_I8_R:
    case R_XTC_32_E8_I8:
        //printf("Insn: %04lx , val %ld == ", xtc_get16(dest), value);
        xtc_put16( (xtc_get16(dest) & 0xF00F) | ((value<<4)&0xff0), dest);
        //printf("%04lx\n", xtc_get16(dest));
        value>>=8;
        dest+=2;
        // Apply extension
        xtc_put16( (xtc_get16(dest) & 0xFF00) | ((value)&0xff), dest);
        //abort();
        break;

    case R_XTC_32_I8_R:
    case R_XTC_32_I8:
        //printf("Insn: %04lx ", xtc_get16(dest));
        xtc_put16( (xtc_get16(dest) & 0xF00F) | ((value<<4)&0xff0), dest);
        //printf("Emit for instruction 0x%04lx, immed is %ld\n",xtc_get16(dest),value);
        break;
    }
}

static bfd_boolean xtc_can_remove_extension(unsigned char *loc)
{
    long insn = xtc_get16(loc+2);
    return (insn & 0x2f00)==0; // Either CC or DREG
}

static void xtc_relax_e24_e8_to_e8(unsigned char *location, long *value)
{
#if 1
    printf("E24E8->E8: %02x%02x %02x%02x %02x%02x %02x%02x to ",
           location[0],
           location[1],
           location[2],
           location[3],
           location[4],
           location[5],
           location[6],
           location[7]
          );
    printf("%02x%02x%02x%02x\n",
           location[4],
           location[5],
           location[6],
           location[7]);
#endif
    if (value) {
        *value -= 4;
    }

}

static int xtc_relax_relocation(int *rel, long value,  unsigned char *location)
{
#define NEW_RELOC_IF(bits,newrel,removedbytes, algo) \
    if (xtc_fits_imm(value,bits)) { (*rel)=(newrel); retry=TRUE; algo(location+bytes, xtc_reloc_pcrel(*rel) ? &value : NULL); bytes+=removedbytes; break; } \
    else { printf("Imm %ld does not fit %d bits\n", value,bits); }
    int bytes = 0;
    bfd_boolean retry;

    do {
        retry = FALSE;
        //printf("Loop\n");
        switch (*rel)
        {
        case R_XTC_32_E24_E8_R:
        case R_XTC_32_E24_E8:
            /* This reloc uses an extra extension because it has some condition code.
             We can only remove the extension immed. */

            
            NEW_RELOC_IF(8, xtc_reloc_pcrel(*rel)? R_XTC_32_E8_R : R_XTC_32_E8, 4,xtc_relax_e24_e8_to_e8);
            //abort();
            break;

        case R_XTC_32_E24_I8_R:
        case R_XTC_32_E24_I8:
            NEW_RELOC_IF(16, xtc_reloc_pcrel(*rel)? R_XTC_32_E8_I8_R : R_XTC_32_E8_I8, 2, xtc_relax_e24_i8_to_e8_i8);
            break;

        case R_XTC_32_E24_R:
        case R_XTC_32_E24:
            NEW_RELOC_IF(8, xtc_reloc_pcrel(*rel)? R_XTC_32_E8_R : R_XTC_32_E8, 2, xtc_relax_e24_to_e8);
            break;

        case R_XTC_32_E8_R:
        case R_XTC_32_E8:
            if (!xtc_can_remove_extension(location+bytes)) {
                break;
            }
            NEW_RELOC_IF(0, R_XTC_NONE, 2, xtc_relax_e8_to_none);
            break;

        case R_XTC_32_E8_I8_R:
        case R_XTC_32_E8_I8:
            if (!xtc_can_remove_extension(location+bytes)) {
                //printf("Cannot remove extension\n");
                break;
            }
            NEW_RELOC_IF(8, xtc_reloc_pcrel(*rel)? R_XTC_32_I8_R : R_XTC_32_I8, 2,xtc_relax_e8_i8_to_i8);
            break;

            /* We cannot relax this any further */
            return -1;
        }
    } while (retry);

    /* Apply relocation value */
    xtc_emit_relocation(*rel,value, location+bytes);
    return bytes;
}



static bfd_boolean
xtc_elf_relax_section (bfd *abfd,
                          asection *sec,
                          struct bfd_link_info *link_info,
                          bfd_boolean *again)
{
    Elf_Internal_Shdr *symtab_hdr;
    Elf_Internal_Rela *internal_relocs;
    Elf_Internal_Rela *free_relocs = NULL;
    Elf_Internal_Rela *irel, *irelend;
    bfd_byte *contents = NULL;
    bfd_byte *free_contents = NULL;
    int rel_count;
    // unsigned int shndx;
    //int i;
    //int sym_index;
    //asection *o;
    //struct elf_link_hash_entry *sym_hash;
    Elf_Internal_Sym *isymbuf;//, *isymend;
    Elf_Internal_Sym *isym;
    int symcount;
    //int offset;
    //bfd_vma src, dest;

    /* We only do this once per section.  We may be able to delete some code
     by running multiple passes, but it is not worth it.  */
    *again = FALSE;

    /* Only do this for a text section.  */
    if (link_info->relocatable
        || (sec->flags & SEC_RELOC) == 0
        || (sec->reloc_count == 0))
        return TRUE;

    BFD_ASSERT ((sec->size > 0) || (sec->rawsize > 0));

    /* If this is the first time we have been called for this section,
     initialize the cooked size.  */
    if (sec->size == 0)
        sec->size = sec->rawsize;

    /* Get symbols for this section.  */
    symtab_hdr = &elf_tdata (abfd)->symtab_hdr;
    isymbuf = (Elf_Internal_Sym *) symtab_hdr->contents;
    symcount =  symtab_hdr->sh_size / sizeof (Elf32_External_Sym);
    if (isymbuf == NULL)
        isymbuf = bfd_elf_get_elf_syms (abfd, symtab_hdr, symcount,
                                        0, NULL, NULL, NULL);
    BFD_ASSERT (isymbuf != NULL);

    internal_relocs = _bfd_elf_link_read_relocs (abfd, sec, NULL, NULL, link_info->keep_memory);
    if (internal_relocs == NULL)
        goto error_return;
    if (! link_info->keep_memory)
        free_relocs = internal_relocs;

    sec->relax = (struct relax_table *) bfd_malloc ((sec->reloc_count + 1)
                                                    * sizeof (struct relax_table));
    if (sec->relax == NULL)
        goto error_return;
    sec->relax_count = 0;

    irelend = internal_relocs + sec->reloc_count;
    rel_count = 0;

    //printf("Doing relaxation pass....\n");

    for (irel = internal_relocs; irel < irelend; irel++, rel_count++)
    {
        bfd_vma symval;

#if 0
        if ((ELF32_R_TYPE (irel->r_info) != (int) R_XTC_32_E8_I8)
            && (ELF32_R_TYPE (irel->r_info) != (int) R_XTC_32_E24_E8 )
            && (ELF32_R_TYPE (irel->r_info) != (int) R_XTC_32_E24_I8 )
            && (ELF32_R_TYPE (irel->r_info) != (int) R_XTC_32_E8_I8_R )
            && (ELF32_R_TYPE (irel->r_info) != (int) R_XTC_32_E24_I8_R )
            && (ELF32_R_TYPE (irel->r_info) != (int) R_XTC_32_E24_E8_R )
           )
            continue; /* Can't delete this reloc.  */
#endif
        /* Get the section contents.  */
        if (contents == NULL)
        {
            if (elf_section_data (sec)->this_hdr.contents != NULL)
                contents = elf_section_data (sec)->this_hdr.contents;
            else
            {
                contents = (bfd_byte *) bfd_malloc (sec->size);
                if (contents == NULL)
                    goto error_return;
                free_contents = contents;

                if (!bfd_get_section_contents (abfd, sec, contents,
                                               (file_ptr) 0, sec->size))
                    goto error_return;
                elf_section_data (sec)->this_hdr.contents = contents;
            }
        }

        /* Get the value of the symbol referred to by the reloc.  */
        if (ELF32_R_SYM (irel->r_info) < symtab_hdr->sh_info)
        {
            /* A local symbol.  */
            asection *sym_sec;

            isym = isymbuf + ELF32_R_SYM (irel->r_info);
            if (isym->st_shndx == SHN_UNDEF)
                sym_sec = bfd_und_section_ptr;
            else if (isym->st_shndx == SHN_ABS)
                sym_sec = bfd_abs_section_ptr;
            else if (isym->st_shndx == SHN_COMMON)
                sym_sec = bfd_com_section_ptr;
            else
                sym_sec = bfd_section_from_elf_index (abfd, isym->st_shndx);

            symval = _bfd_elf_rela_local_sym (abfd, isym, &sym_sec, irel);
        }
        else
        {
            unsigned long indx;
            struct elf_link_hash_entry *h;

            indx = ELF32_R_SYM (irel->r_info) - symtab_hdr->sh_info;
            h = elf_sym_hashes (abfd)[indx];
            BFD_ASSERT (h != NULL);

            if (h->root.type != bfd_link_hash_defined
                && h->root.type != bfd_link_hash_defweak)
                /* This appears to be a reference to an undefined
                 symbol.  Just ignore it--it will be caught by the
                 regular reloc processing.  */
                continue;

            symval = (h->root.u.def.value
                      + h->root.u.def.section->output_section->vma
                      + h->root.u.def.section->output_offset);
        }
        //int isPcrel = 0;

        if (xtc_reloc_pcrel( ELF32_R_TYPE( irel->r_info )))
        {
            //isPcrel = 1;
            int offset = xtc_reloc_pcrel_offset(ELF32_R_TYPE( irel->r_info ));
          //  printf("Offset for reloc: %d\n",offset);
            symval = symval + irel->r_addend
                - (irel->r_offset + offset +
                   + sec->output_section->vma
                   + sec->output_offset);
        }
        else
            symval += irel->r_addend;


        bfd_vma value = symval;


        int newReloc = ELF32_R_TYPE(irel->r_info);
        int deleteBytes = 0;
        //printf("Reloc at 0x%lx (value: %ld)\n",irel->r_offset,value);
        deleteBytes = xtc_relax_relocation(&newReloc, value, elf_section_data (sec)->this_hdr.contents + irel->r_offset);

        if (deleteBytes) {

            elf_section_data (sec)->relocs = internal_relocs;
            free_relocs = NULL;

            elf_section_data (sec)->this_hdr.contents = contents;
            free_contents = NULL;

            symtab_hdr->contents = (bfd_byte *) isymbuf;
            //free_extsyms = NULL;

            irel->r_info = ELF32_R_INFO (ELF32_R_SYM (irel->r_info), newReloc );
            
            xtc_elf_relax_delete_bytes (abfd, sec, irel->r_offset, deleteBytes);

            // Emit relocation
            /*
            xtc_emit_relocation(newReloc, value,
                                elf_section_data (sec)->this_hdr.contents + irel->r_offset);
            */
            *again = TRUE;

        }
    } /* Loop through all relocations.  */

    if (free_relocs != NULL)
    {
        free (free_relocs);
        free_relocs = NULL;
    }

    if (free_contents != NULL)
    {
        if (!link_info->keep_memory)
            free (free_contents);
        else
            /* Cache the section contents for elf_link_input_bfd.  */
            elf_section_data (sec)->this_hdr.contents = contents;
        free_contents = NULL;
    }

    if (sec->relax_count == 0)
    {
        free (sec->relax);
        sec->relax = NULL;
    }
    return TRUE;

error_return:
    if (free_relocs != NULL)
        free (free_relocs);
    if (free_contents != NULL)
        free (free_contents);
    if (sec->relax != NULL)
    {
        free (sec->relax);
        sec->relax = NULL;
        sec->relax_count = 0;
    }
    return FALSE;
}






static bfd_boolean
xtc_elf_create_dynamic_sections (bfd *dynobj ATTRIBUTE_UNUSED,
                                 struct bfd_link_info *info ATTRIBUTE_UNUSED)
{
  return FALSE;
}

static bfd_boolean
xtc_elf_adjust_dynamic_symbol (struct bfd_link_info *info ATTRIBUTE_UNUSED,
                               struct elf_link_hash_entry *h ATTRIBUTE_UNUSED)
{
  return FALSE;
}

/* Set the sizes of the dynamic sections.  */

static bfd_boolean
xtc_elf_size_dynamic_sections (bfd *output_bfd ATTRIBUTE_UNUSED,
                               struct bfd_link_info *info ATTRIBUTE_UNUSED)
{
  return FALSE;
}

/* Finish up dynamic symbol handling.  We set the contents of various
   dynamic sections here.  */

static bfd_boolean
xtc_elf_finish_dynamic_symbol (bfd *output_bfd ATTRIBUTE_UNUSED,
                               struct bfd_link_info *info ATTRIBUTE_UNUSED,
                               struct elf_link_hash_entry *h ATTRIBUTE_UNUSED,
                               Elf_Internal_Sym *sym ATTRIBUTE_UNUSED)
{
  
  return FALSE;
}


/* Finish up the dynamic sections.  */

static bfd_boolean
xtc_elf_finish_dynamic_sections (bfd *output_bfd ATTRIBUTE_UNUSED,
                                 struct bfd_link_info *info ATTRIBUTE_UNUSED)
{
  return FALSE;
}





















#define TARGET_BIG_SYM          bfd_elf32_xtc_vec
#define TARGET_BIG_NAME		"elf32-xtc"

#define ELF_ARCH		bfd_arch_xtc
#define ELF_TARGET_ID		XTC_ELF_DATA
#define ELF_MACHINE_CODE	EM_XTC
#define ELF_MAXPAGESIZE		0x4   		/* 4k, if we ever have 'em.  */
#define elf_info_to_howto	xtc_elf_info_to_howto
#define elf_info_to_howto_rel	NULL

#define bfd_elf32_bfd_reloc_type_lookup		xtc_elf_reloc_type_lookup
//#define bfd_elf32_bfd_is_local_label_name       xtc_elf_is_local_label_name
#define elf_backend_relocate_section		xtc_elf_relocate_section
#define bfd_elf32_bfd_relax_section             xtc_elf_relax_section
#define bfd_elf32_bfd_reloc_name_lookup		xtc_elf_reloc_name_lookup

//#define elf_backend_gc_mark_hook		xtc_elf_gc_mark_hook
//#define elf_backend_gc_sweep_hook		xtc_elf_gc_sweep_hook
#define elf_backend_check_relocs                xtc_elf_check_relocs
//#define elf_backend_copy_indirect_symbol        xtc_elf_copy_indirect_symbol
#define bfd_elf32_bfd_link_hash_table_create    xtc_elf_link_hash_table_create
#define elf_backend_can_gc_sections		1
//#define elf_backend_can_refcount    		1
//#define elf_backend_want_got_plt                0
//#define elf_backend_plt_readonly    		1
//#define elf_backend_got_header_size 		12
#define elf_backend_rela_normal     		1

#define elf_backend_adjust_dynamic_symbol       xtc_elf_adjust_dynamic_symbol
#define elf_backend_create_dynamic_sections     xtc_elf_create_dynamic_sections
#define elf_backend_finish_dynamic_sections     xtc_elf_finish_dynamic_sections
#define elf_backend_finish_dynamic_symbol       xtc_elf_finish_dynamic_symbol
#define elf_backend_size_dynamic_sections       xtc_elf_size_dynamic_sections
//#define elf_backend_add_symbol_hook		xtc_elf_add_symbol_hook

#include "elf32-target.h"

