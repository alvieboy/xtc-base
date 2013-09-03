#include "sysdep.h"
#include "bfd.h"
#include "bfdlink.h"
#include "libbfd.h"
#include "elf-bfd.h"
#include "elf/newcpu.h"
#include <assert.h>

static reloc_howto_type * newcpu_elf_howto_table [(int) R_NEWCPU_max];

static reloc_howto_type newcpu_elf_howto_raw[] =
{
   /* This reloc does nothing.  */
   HOWTO (R_NEWCPU_NONE,	/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          32,			/* Bitsize.  */
          FALSE,		/* PC_relative.  */
          0,			/* Bitpos.  */
          complain_overflow_bitfield,  /* Complain on overflow.  */
          NULL,                  /* Special Function.  */
          "R_NEWCPU_NONE", 	/* Name.  */
          FALSE,		/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0,			/* Dest Mask.  */
          FALSE),		/* PC relative offset?  */

   /* A standard 32 bit relocation.  */
   HOWTO (R_NEWCPU_32,     	/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          32,			/* Bitsize.  */
          FALSE,		/* PC_relative.  */
          0,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          bfd_elf_generic_reloc,/* Special Function.  */
          "R_NEWCPU_32",   	/* Name.  */
          FALSE,		/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0xffffffff,		/* Dest Mask.  */
          FALSE), 		/* PC relative offset?  */

   /* A standard PCREL 32 bit relocation.  */
   HOWTO (R_NEWCPU_32_PCREL,/* Type.  */
          0,			/* Rightshift.  */
          2,			/* Size (0 = byte, 1 = short, 2 = long).  */
          32,			/* Bitsize.  */
          TRUE,			/* PC_relative.  */
          0,			/* Bitpos.  */
          complain_overflow_bitfield, /* Complain on overflow.  */
          bfd_elf_generic_reloc,/* Special Function.  */
          "R_NEWCPU_32_PCREL",   	/* Name.  */
          TRUE,			/* Partial Inplace.  */
          0,			/* Source Mask.  */
          0xffffffff,		/* Dest Mask.  */
          TRUE)  		/* PC relative offset?  */
};

#ifndef NUM_ELEM
#define NUM_ELEM(a) (sizeof (a) / sizeof (a)[0])
#endif

static void
newcpu_elf_howto_init (void)
{
  unsigned int i;

  for (i = NUM_ELEM (newcpu_elf_howto_raw); i--;)
    {
      unsigned int type;

      type = newcpu_elf_howto_raw[i].type;

      BFD_ASSERT (type < NUM_ELEM (newcpu_elf_howto_table));

      newcpu_elf_howto_table [type] = & newcpu_elf_howto_raw [i];
    }
}

static reloc_howto_type *
newcpu_elf_reloc_type_lookup (bfd * abfd ATTRIBUTE_UNUSED,
				  bfd_reloc_code_real_type code)
{
  enum elf_newcpu_reloc_type newcpu_reloc = R_NEWCPU_NONE;

  switch (code)
    {
    case BFD_RELOC_NONE:
      newcpu_reloc = R_NEWCPU_NONE;
      break;
    case BFD_RELOC_32:
      newcpu_reloc = R_NEWCPU_32;
      break;
      /* RVA is treated the same as 32 */
    case BFD_RELOC_RVA:
      newcpu_reloc = R_NEWCPU_32;
      break;
    case BFD_RELOC_32_PCREL:
      newcpu_reloc = R_NEWCPU_32_PCREL;
      break;
/*    case BFD_RELOC_NEWCPU_COPY:
      newcpu_reloc = R_NEWCPU_COPY;
      break;
      */
    default:
      return (reloc_howto_type *) NULL;
    }

  if (!newcpu_elf_howto_table [R_NEWCPU_32])
    /* Initialize howto table if needed.  */
    newcpu_elf_howto_init ();

  return newcpu_elf_howto_table [(int) newcpu_reloc];
};

static reloc_howto_type *
newcpu_elf_reloc_name_lookup (bfd *abfd ATTRIBUTE_UNUSED,
				  const char *r_name)
{
  unsigned int i;

  for (i = 0; i < NUM_ELEM (newcpu_elf_howto_raw); i++)
    if (newcpu_elf_howto_raw[i].name != NULL
	&& strcasecmp (newcpu_elf_howto_raw[i].name, r_name) == 0)
      return &newcpu_elf_howto_raw[i];

  return NULL;
}

/* Set the howto pointer for a RCE ELF reloc.  */

static void
newcpu_elf_info_to_howto (bfd * abfd ATTRIBUTE_UNUSED,
			      arelent * cache_ptr,
			      Elf_Internal_Rela * dst)
{
  if (!newcpu_elf_howto_table [R_NEWCPU_32])
    /* Initialize howto table if needed.  */
    newcpu_elf_howto_init ();

  BFD_ASSERT (ELF32_R_TYPE (dst->r_info) < (unsigned int) R_NEWCPU_max);

  cache_ptr->howto = newcpu_elf_howto_table [ELF32_R_TYPE (dst->r_info)];
}

#define TARGET_BIG_SYM          bfd_elf32_newcpu_vec
#define TARGET_BIG_NAME		"elf32-newcpu"

#define ELF_ARCH		bfd_arch_newcpu
#define ELF_TARGET_ID		NEWCPU_ELF_DATA
#define ELF_MACHINE_CODE	EM_NEWCPU
#define ELF_MAXPAGESIZE		0x4   		/* 4k, if we ever have 'em.  */
#define elf_info_to_howto	newcpu_elf_info_to_howto
#define elf_info_to_howto_rel	NULL

#define bfd_elf32_bfd_reloc_type_lookup		newcpu_elf_reloc_type_lookup
//#define bfd_elf32_bfd_is_local_label_name       newcpu_elf_is_local_label_name
//#define elf_backend_relocate_section		newcpu_elf_relocate_section
//#define bfd_elf32_bfd_relax_section             newcpu_elf_relax_section
#define bfd_elf32_bfd_reloc_name_lookup		newcpu_elf_reloc_name_lookup

//#define elf_backend_gc_mark_hook		newcpu_elf_gc_mark_hook
//#define elf_backend_gc_sweep_hook		newcpu_elf_gc_sweep_hook
//#define elf_backend_check_relocs                newcpu_elf_check_relocs
//#define elf_backend_copy_indirect_symbol        newcpu_elf_copy_indirect_symbol
//#define bfd_elf32_bfd_link_hash_table_create    newcpu_elf_link_hash_table_create
#define elf_backend_can_gc_sections		1
#define elf_backend_can_refcount    		1
#define elf_backend_want_got_plt    		1
#define elf_backend_plt_readonly    		1
#define elf_backend_got_header_size 		12
#define elf_backend_rela_normal     		1

//#define elf_backend_adjust_dynamic_symbol       newcpu_elf_adjust_dynamic_symbol
//#define elf_backend_create_dynamic_sections     newcpu_elf_create_dynamic_sections
//#define elf_backend_finish_dynamic_sections     newcpu_elf_finish_dynamic_sections
//#define elf_backend_finish_dynamic_symbol       newcpu_elf_finish_dynamic_symbol
//#define elf_backend_size_dynamic_sections       newcpu_elf_size_dynamic_sections
//#define elf_backend_add_symbol_hook		newcpu_elf_add_symbol_hook

#include "elf32-target.h"
