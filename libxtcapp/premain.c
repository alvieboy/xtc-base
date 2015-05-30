#include "serial.h"

extern void outbyte(int);
extern void register_sd();
extern void __posix_init();
extern void __trace_set_memmatch(unsigned);
extern unsigned char __malloc_av_;

void _premain()
{
    __posix_init();
    serial_register_device("serial0", (void*)0x90000000);
    register_sd();
}
