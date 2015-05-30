#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "cpu.h"

uint32_t xtc_read_mem_u32(unsigned char *addr){
    uint32_t r;
    r = ((uint32_t)(*addr++))<<24;
    r+= ((uint32_t)(*addr++))<<16;
    r+= ((uint32_t)(*addr++))<<8;
    r+= ((uint32_t)(*addr));
    return r;
}

uint16_t xtc_read_mem_u16(unsigned char *addr){
    uint16_t r;
    r= ((uint16_t)(*addr++))<<8;
    r+= ((uint16_t)(*addr));
    return r;
}

uint8_t xtc_read_mem_u8(unsigned char *addr) {
    uint8_t r;
    r = ((uint8_t)(*addr));
    return r;

}

void xtc_store_mem_u32(unsigned char *addr, uint32_t val)
{
    *addr++ = val>>24;
    *addr++ = val>>16;
    *addr++ = val>>8;
    *addr = val;
}
void xtc_store_mem_u16(unsigned char *addr, uint16_t val)
{
    *addr++ = val>>8;
    *addr = val;
}
void xtc_store_mem_u8(unsigned char *addr, uint8_t val)
{
    *addr = val;
}

cpu_word_t xtc_get_spr(xtc_cpu_t *cpu, int index)
{
    index&=7;
    return cpu->spr.v[index];
}

void xtc_set_spr(xtc_cpu_t *cpu, int index, cpu_word_t value)
{
    index&=7;
    cpu->spr.v[index] = value;
    /* TODO: handle setting PC */
}


xtc_cpu_t *initialize()
{
    xtc_cpu_t *cpu = malloc(sizeof(xtc_cpu_t));
    cpu->memsize = 16384;
    cpu->memory = malloc(cpu->memsize);
    memset(cpu->memory,0x00,cpu->memsize);
    memset(&cpu->spr, 0, sizeof(cpu->spr));
    cpu->imm = 0;
    cpu->imflag = 0;
    cpu->branchNext = -1;
    memset(cpu->regs, 0, sizeof(cpu->regs));
    return cpu;
}
