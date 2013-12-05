#include <stdlib.h>
#include <stdio.h>

#include "memory.h"
#include "io.h"

void handle_store(xtc_cpu_t *cpu, unsigned reg_addr, unsigned reg_val, int offset)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;
    realaddr &= ~3;

    if (realaddr < cpu->memsize) {
        xtc_store_mem_u32( &cpu->memory[realaddr], cpu->regs[reg_val]);
    } else {
        if (IS_IO(realaddr)) {
            handle_store_io( realaddr, cpu->regs[reg_val] );
        } else {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
}

void handle_store_short(xtc_cpu_t *cpu, unsigned reg_addr, unsigned reg_val, int offset)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;
    realaddr &= ~1;

    if (realaddr < cpu->memsize) {
        xtc_store_mem_u16( &cpu->memory[realaddr], cpu->regs[reg_val]);
    } else {
        if (IS_IO(realaddr)) {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
}

void handle_store_byte(xtc_cpu_t *cpu, unsigned reg_addr, unsigned reg_val, int offset)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;
    if (realaddr < cpu->memsize) {
        xtc_store_mem_u8( &cpu->memory[realaddr], cpu->regs[reg_val]);
    } else {
        if (IS_IO(realaddr)) {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
}

cpu_word_t handle_read(xtc_cpu_t *cpu, unsigned reg_addr, int offset)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;
    realaddr &= ~3;

    if (realaddr < cpu->memsize) {
        return xtc_read_mem_u32( &cpu->memory[realaddr]);
    } else {
        if (IS_IO(realaddr)) {
            return handle_read_io( realaddr );
        } else {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
    return 0;
}

cpu_word_t handle_read_short(xtc_cpu_t *cpu, unsigned reg_addr, int offset)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;
    realaddr &= ~1;

    if (realaddr < cpu->memsize) {
        return xtc_read_mem_u16( &cpu->memory[realaddr]);
    } else {
        if (IS_IO(realaddr)) {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
    return 0;
}

cpu_word_t handle_read_byte(xtc_cpu_t *cpu, unsigned reg_addr, int offset)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;

    if (realaddr < cpu->memsize) {
        return xtc_read_mem_u8( &cpu->memory[realaddr]);
    } else {
        if (IS_IO(realaddr)) {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
    return 0;
}
