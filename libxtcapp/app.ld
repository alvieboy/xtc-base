/* Script for -n: mix text and data on same page */
OUTPUT_FORMAT("elf32-xtc", "","")
ENTRY (_start)

_TEXT_START_ADDR = DEFINED(_TEXT_START_ADDR) ? _TEXT_START_ADDR : 0x00000000;
_HEAP_SIZE = DEFINED(_HEAP_SIZE) ? _HEAP_SIZE : 0x0;
_STACK_SIZE = DEFINED(_STACK_SIZE) ? _STACK_SIZE : 0x8000;
SECTIONS
{
  . = _TEXT_START_ADDR;
  .vectors 0x00000000 : {
  	*(.vectors)
  }
  . = ALIGN(128);
  _trapbegin = .;
  .trap0 : {
  	*(.trap0)
  }
  . = _trapbegin + 16;
  .trap1 : {
  	*(.trap1)
  }
  . = _trapbegin + 32;
  .trap2 : {
  	*(.trap2)
  }
  . = _trapbegin + 48;
  .trap3 : {
  	*(.trap3)
  }
  . = _trapbegin + 64;
  .trap4 : {
  	*(.trap4)
  }


   _ftext  =  .;
  .text : {
    *(.text)
    *(.text.*)
    *(.gnu.linkonce.t.*)
  }
   _etext  =  .;
  .init : { KEEP (*(.init))	} =0
  .fini : { KEEP (*(.fini))	} =0
  PROVIDE (__CTOR_LIST__ = .);
  PROVIDE (___CTOR_LIST__ = .);
  .ctors   :
  {
    /* gcc uses crtbegin.o to find the start of
       the constructors, so we make sure it is
       first.  Because this is a wildcard, it
       doesn't matter if the user does not
       actually link against crtbegin.o; the
       linker won't look for a file to match a
       wildcard.  The wildcard also means that it
       doesn't matter which directory crtbegin.o
       is in.  */
    KEEP (*crtbegin.o(.ctors))
    /* We don't want to include the .ctor section from
       from the crtend.o file until after the sorted ctors.
       The .ctor section from the crtend file contains the
       end of ctors marker and it must be last */
    KEEP (*(EXCLUDE_FILE (*crtend.o) .ctors))
    KEEP (*(SORT(.ctors.*)))
    KEEP (*(.ctors))
  }
  PROVIDE (__CTOR_END__ = .);
  PROVIDE (___CTOR_END__ = .);
  PROVIDE (__DTOR_LIST__ = .);
  PROVIDE (___DTOR_LIST__ = .);
   .dtors         :
  {
    KEEP (*crtbegin.o(.dtors))
    KEEP (*(EXCLUDE_FILE (*crtend.o) .dtors))
    KEEP (*(SORT(.dtors.*)))
    KEEP (*(.dtors))
  }
  PROVIDE (__DTOR_END__ = .);
  PROVIDE (___DTOR_END__ = .);
   . = ALIGN(4);
    _frodata = . ;
  .rodata : {
    *(.rodata)
    *(.rodata.*)
    *(.gnu.linkonce.r.*)
    CONSTRUCTORS; /* Is this needed? */
  }
   _erodata = .;

  . = ALIGN(8);
   _fdata = .;
  .data : {
    *(.data)
    *(.gnu.linkonce.d.*)
    CONSTRUCTORS; /* Is this needed? */
  }
   _edata = . ;
   /* Added to handle pic code */
  .got : {
    *(.got)
  }
  .got1 : {
    *(.got1)
  }
  .got2 : {
    *(.got2)
  }
  /* Added by Sathya to handle C++ exceptions */
  .eh_frame : {
    *(.eh_frame)
  }
  .jcr : {
    *(.jcr)
  }
  .gcc_except_table : {
    *(.gcc_except_table)
  }
   . = ALIGN(4);
   _fbss = .;
  .bss : {
    PROVIDE (__bss_start = .);
    *(.bss)
    *(.bss.*)
    *(.gnu.linkonce.b.*)
    *(COMMON)
    . = ALIGN(4);
    PROVIDE (__bss_end = .);
  }
   . = ALIGN(4);
  .memfile : {
  	PROVIDE(__mem_file_start = .);
  	*(.memfile)
  	PROVIDE(__mem_file_end = .);
  }
   . = ALIGN(4);
  .heap : {
     _heap = .;
     _heap_start = .;
     . += _HEAP_SIZE;
     _heap_end = .;
  }
   . = ALIGN(4);
  .stack : {
     _stack_end = .;
     . += _STACK_SIZE;
     . = ALIGN(8);
     _stack = .;
     _end = .;
  }
}
