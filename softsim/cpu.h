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

#endif
