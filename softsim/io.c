#include "io.h"
#include <stdio.h>
#include <stdlib.h>

void handle_store_io(cpu_pointer_t address, cpu_word_t value)
{
    /* UART only..*/
    if ((address&0x7ffffff0)==0) {
        if ((address&0xf)==0) {
            printf("%c", value&0xff);
            fflush(stdout);
        }
    } else {
        printf("Invalid access to address 0x%08x\n", address);
        abort();
    }
}

cpu_word_t handle_read_io(cpu_pointer_t address)
{
    return 0;
}

