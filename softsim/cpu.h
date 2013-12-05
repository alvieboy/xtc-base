#ifndef __XTCCPU_H__
#define __XTCCPU_H__
#include <inttypes.h>

typedef uint32_t cpu_pointer_t;
typedef uint32_t cpu_word_t;

typedef struct xtc_cpu {
    unsigned memsize;
    unsigned char *memory;
    cpu_word_t regs[32];
    cpu_word_t pc, npc, br, y;
    unsigned zero, carry;
    unsigned imm;
    int imflag;
    unsigned branchNext;
    int resetImmed;
} xtc_cpu_t;

#define IS_IO(x) (x&0x80000000)

typedef uint16_t inst_t;

uint32_t xtc_read_mem_u32(unsigned char *addr);
uint16_t xtc_read_mem_u16(unsigned char *addr);
uint8_t xtc_read_mem_u8(unsigned char *addr);

void xtc_store_mem_u32(unsigned char *addr, uint32_t val);
void xtc_store_mem_u16(unsigned char *addr, uint16_t val);
void xtc_store_mem_u8(unsigned char *addr, uint8_t val);

xtc_cpu_t *initialize();

#endif
