#ifndef __MEMORY_H__
#define __MEMORY_H__

#include "cpu.h"

void       handle_store(xtc_cpu_t *cpu,
                        unsigned reg_addr, 
                        unsigned reg_val, 
                        int offset);
void       handle_store_short(xtc_cpu_t *cpu,
                              unsigned reg_addr,
                              unsigned reg_val, 
                              int offset);
void       handle_store_byte(xtc_cpu_t *cpu,
                             unsigned reg_addr,
                             unsigned reg_val, 
                             int offset);

cpu_word_t handle_read(xtc_cpu_t *cpu, unsigned reg_addr, int offset);
cpu_word_t handle_read_short(xtc_cpu_t *cpu, unsigned reg_addr, int offset);
cpu_word_t handle_read_byte(xtc_cpu_t *cpu, unsigned reg_addr, int offset);

#endif
