#ifndef __XTCCPU_H__
#define __XTCCPU_H__
#include <inttypes.h>

typedef struct xtc_cpu {
    unsigned memsize;
    unsigned char *memory;
    unsigned regs[32];
    unsigned pc, br, y;
    unsigned zero, carry;
    unsigned imm;
    int imflag;

} xtc_cpu_t;

typedef uint16_t inst_t;

#endif
