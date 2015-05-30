#ifndef __DECODE_H__
#define __DECODE_H__

#define UNKNOWN_OP(op) \
do { \
    printf("Invalid opcode %04x, PC 0x%08x\n", op,cpu->spr.r.pc);\
    abort();\
} while (0)

#define UNHANDLED_OP(name,op) \
do { \
    printf("Unhandled opcode %s %04x, PC 0x%08x. Fill in a bug report\n", name,op,cpu->spr.r.pc); \
    abort(); \
} while (0)


int decode_single_opcode(xtc_cpu_t*cpu, unsigned op, opcode_t *opcode);

#endif /* __DECODE_H__ */