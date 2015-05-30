#ifndef __XTCCPU_H__
#define __XTCCPU_H__
#include <inttypes.h>

typedef uint32_t cpu_pointer_t;
typedef uint32_t cpu_word_t;

union xtc_spr {
    cpu_word_t v[8];
    struct {
        cpu_word_t pc;
        cpu_word_t br;
        cpu_word_t y;
        cpu_word_t _u1;
        cpu_word_t _u2;
        cpu_word_t _u3;
        cpu_word_t _u4;
        cpu_word_t _u5;
    } r;
};

typedef struct xtc_cpu {
    unsigned memsize;
    unsigned char *memory;
    cpu_word_t regs[32];
    cpu_word_t npc;
    union xtc_spr spr;
    unsigned zero, carry, sign;
    unsigned imm;
    int imflag;
    unsigned branchNext;
    int resetImmed;
} xtc_cpu_t;

#define IS_IO(x) (x&0x80000000)

typedef uint16_t inst_t;

cpu_word_t xtc_get_spr(xtc_cpu_t *cpu, int index);
void xtc_set_spr(xtc_cpu_t *cpu, int index, cpu_word_t value);

uint32_t xtc_read_mem_u32(unsigned char *addr);
uint16_t xtc_read_mem_u16(unsigned char *addr);
uint8_t xtc_read_mem_u8(unsigned char *addr);

void xtc_store_mem_u32(unsigned char *addr, uint32_t val);
void xtc_store_mem_u16(unsigned char *addr, uint16_t val);
void xtc_store_mem_u8(unsigned char *addr, uint8_t val);

xtc_cpu_t *initialize();

#endif
