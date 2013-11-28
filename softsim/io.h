#ifndef __IO_H__
#define __IO_H__

#include "cpu.h"

void handle_store_io(cpu_pointer_t address, cpu_word_t value);
cpu_word_t handle_read_io(cpu_pointer_t address);

#endif
