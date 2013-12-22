#include <stdlib.h>
#include <stdio.h>

#include "memory.h"
#include "io.h"

#define assert(x) \
    do { \
    if (!(x)) {\
    fprintf(stderr,"Error: assertion %s failed\n", #x); \
    abort(); \
    }        \
} while (0);

void handle_store_val(xtc_cpu_t *cpu, unsigned reg_addr, unsigned val, int offset,FILE*stream)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;
    assert((realaddr&3) == 0);

    realaddr &= ~3;

    if (realaddr < cpu->memsize) {
        fprintf(stream,"/* Addr: 0x%08x, Val: 0x%08x */",realaddr,val);
        xtc_store_mem_u32( &cpu->memory[realaddr], val);
    } else {
        if (IS_IO(realaddr)) {
            fprintf(stream,"/* IO Addr: 0x%08x, Val: 0x%08x */",realaddr,val);
            handle_store_io( realaddr, val);
        } else {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
}

void handle_store(xtc_cpu_t *cpu, unsigned reg_addr, unsigned reg_val, int offset,FILE*stream)
{
    handle_store_val(cpu,reg_addr, cpu->regs[reg_val],offset,stream);
}

void handle_store_short(xtc_cpu_t *cpu, unsigned reg_addr, unsigned reg_val, int offset,FILE*stream)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;
    assert((realaddr&1) == 0);
    realaddr &= ~1;

    if (realaddr < cpu->memsize) {
        fprintf(stream,"/* Addr: 0x%08x, Val: 0x%04x */",realaddr,cpu->regs[reg_val]);
        xtc_store_mem_u16( &cpu->memory[realaddr], cpu->regs[reg_val]);
    } else {
        if (IS_IO(realaddr)) {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
}

void handle_store_byte(xtc_cpu_t *cpu, unsigned reg_addr, unsigned reg_val, int offset,FILE*stream)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;
    if (realaddr < cpu->memsize) {
        fprintf(stream,"/* Addr: 0x%08x, Val: 0x%02x */",realaddr,cpu->regs[reg_val]);
        xtc_store_mem_u8( &cpu->memory[realaddr], cpu->regs[reg_val]);
    } else {
        if (IS_IO(realaddr)) {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
}

cpu_word_t handle_read(xtc_cpu_t *cpu, unsigned reg_addr, int offset,FILE*stream)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;
    assert((realaddr&3) == 0);
    realaddr &= ~3;
    cpu_word_t ret;

    if (realaddr < cpu->memsize) {
        ret = xtc_read_mem_u32( &cpu->memory[realaddr]);
        fprintf(stream,"/* Addr: 0x%08x, Val: 0x%08x */",realaddr,ret);
        return ret;
    } else {
        if (IS_IO(realaddr)) {
            ret =  handle_read_io( realaddr );
            fprintf(stream,"/* IO Addr: 0x%08x, Val: 0x%08x */",realaddr,ret);
            return ret;
        } else {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
    return 0;
}

cpu_word_t handle_read_short(xtc_cpu_t *cpu, unsigned reg_addr, int offset,FILE*stream)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;
    assert((realaddr&1) == 0);

    realaddr &= ~1;
    cpu_word_t ret;

    if (realaddr < cpu->memsize) {

        ret = xtc_read_mem_u16( &cpu->memory[realaddr]);
        fprintf(stream,"/* Addr: 0x%08x, Val: 0x%04x */",realaddr,ret);

        return ret;
    } else {
        if (IS_IO(realaddr)) {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
    return 0;
}

cpu_word_t handle_read_byte(xtc_cpu_t *cpu, unsigned reg_addr, int offset,FILE*stream)
{
    /* Check overflow, underflow, manage IO */
    cpu_pointer_t realaddr = cpu->regs[reg_addr] + offset;
    cpu_word_t ret;

    if (realaddr < cpu->memsize) {
        ret = xtc_read_mem_u8( &cpu->memory[realaddr]);
        fprintf(stream,"/* Addr: 0x%08x, Val: 0x%02x */",realaddr,ret);
        return ret;
    } else {
        if (IS_IO(realaddr)) {
            printf("\n\nAttempt to access unmapped region at 0x%08x", realaddr);
            abort();
        }
    }
    return 0;
}
