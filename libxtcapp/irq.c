#include <inttypes.h>
#include "print.h"
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#if 0

inline unsigned int __psr()
{
    register unsigned int v;
    /* If it was a soft interrupt, we need to move pc ahead */
    __asm__ volatile ("rspr psr, %0" : "=r"(v): : );
    return v;

}
#endif
extern unsigned int __psr();
extern unsigned __trace_get_counters();
extern void __trace_set_counter(unsigned);
extern unsigned __trace_get_pc();
extern unsigned __trace_get_lhs();
extern unsigned __trace_get_rhs();
extern unsigned __trace_get_opcode();

extern unsigned __trace_get_mempc();
extern unsigned __trace_get_memaddr();
extern unsigned __trace_get_memdata();
extern void __trace_set_memmatch(unsigned);
extern void __trace_set_memcounter(unsigned);
extern unsigned __trace_get_memcounters();

static void interactive();

struct pt_regs
{
    uint32_t TPC;
    uint32_t SPSR;
    uint32_t R15;
    uint32_t R14;
    uint32_t R13;
    uint32_t R12;
    uint32_t R11;
    uint32_t R10;
    uint32_t R9;
    uint32_t R8;
    uint32_t R7;
    uint32_t R6;
    uint32_t R5;
    uint32_t R4;
    uint32_t R3;
    uint32_t R2;
    uint32_t R1;
};

static void dump_tracebuffer()
{
    unsigned r;
    r = __trace_get_counters();
    unsigned nentries = r>>16;
    if (nentries) {
        printstring("Tracebuffer: \r\n");
        while (nentries--) {
            r++;
            r&=0xffff;
            // E 0x80000000 0xFFFF6000 0xuuuuuuuu 0xuuuuuuuu
            printstring("E 0x");
            __trace_set_counter(r);
            printhex(__trace_get_pc());
            printstring(" 0x");
            unsigned opcode = __trace_get_opcode();
            printhex(opcode);
            printstring(" 0x");
            printhex(__trace_get_lhs());
            printstring(" 0x");
            printhex(__trace_get_rhs());
            printstring("\r\n");
        }
    }
}

static void dump_membuffer()
{
    unsigned r;
    r = __trace_get_memcounters();
    unsigned nentries = r>>16;
    if (nentries) {
        printstring("Membuffer: \r\n");
        while (nentries--) {
            r++;
            r&=0xffff;
            // E 0x80000000 0xFFFF6000 0xuuuuuuuu 0xuuuuuuuu
            printstring("E 0x");
            __trace_set_memcounter(r);
            printhex(__trace_get_mempc());
            printstring(" 0x");
            printhex(__trace_get_memaddr());
            printstring(" 0x");
            printhex(__trace_get_memdata());
            printstring("\r\n");
        }
    }
}



void handle_irq(struct pt_regs *regs)
{

#if 1

    printstring("\r\nException caught at address 0x");
    printhex(regs->TPC);
#define NL \
    printstring("\r\n")
#define DUMPREGS(x) \
    printstring(#x " : "); \
    printhex(regs->x); \
    printstring(" ");
#define DUMPREG(x) \
    printstring(#x ": "); \
    printhex(regs->x); \
    printstring(" ");
    NL;
    printstring("PSR : ");
    printhex( __psr() );
    NL;
    DUMPREG(SPSR);
    NL;
    DUMPREGS(R1);
    DUMPREGS(R2);
    DUMPREGS(R3);
    DUMPREGS(R4);
    NL;
    DUMPREGS(R5);
    DUMPREGS(R6);
    DUMPREGS(R7);
    DUMPREGS(R8);
    NL;
    DUMPREGS(R9);
    DUMPREG(R10);
    DUMPREG(R11);
    DUMPREG(R12);
    NL;
    DUMPREG(R13);
    DUMPREG(R14);
    DUMPREG(R15);
    NL;

    printstring("\r\nEntering interactive mode.\r\n");
    interactive();
#endif

    unsigned psr = (__psr() >> 4) & 0xf;
    if (psr==2) {
        printstring("Returning to next instruction\n");
        regs->TPC+=2;
        return;
    }

}
static volatile unsigned int *base = (volatile unsigned int*)0x90000000;

static int inbyte_nonblock()
{
    if (((*(base+1))&1)==0)
        return -1;
    return (*base)&0xff;
}

static int inbyte()
{
    int r;
    do {
        r=inbyte_nonblock();
    } while (r<0);
    return r;
}


static char line[128];
static int lptr;

static char *__internal_strtok(char *s, const char *delim)
{
    register char *spanp;
    register int c, sc;
    char *tok;
    static char *last;


    if (s == NULL && (s = last) == NULL)
        return (NULL);

    /*
     * Skip (span) leading delimiters (s += strspn(s, delim), sort of).
     */
cont:
    c = *s++;
    for (spanp = (char *)delim; (sc = *spanp++) != 0;) {
        if (c == sc)
            goto cont;
    }

    if (c == 0) {		/* no non-delimiter characters */
        last = NULL;
        return (NULL);
    }
    tok = s - 1;

    /*
	 * Scan token (scan for delimiters: s += strcspn(s, delim), sort of).
	 * Note that delim must have one NUL; we stop if we see that, too.
         */
    for (;;) {
        c = *s++;
        spanp = (char *)delim;
        do {
            if ((sc = *spanp++) == c) {
                if (c == 0)
                    s = NULL;
                else
                    s[-1] = 0;
                last = s;
                return (tok);
            }
        } while (sc != 0);
    }
    /* NOTREACHED */
}

static int split(char *str, char **target, int size)
{
    int cur=0;
    char *t = __internal_strtok(str," ");
    target[cur++] = t;
    do {
        t = __internal_strtok(NULL," ");
        target[cur++] = t;
        if (cur==size)
            return -1;
    } while (t);
    return cur;
}

static int mystrtol(const char *str, unsigned *dest, int base)
{
    if ((NULL==str) || str[0]=='\0')
        return -1;

    const char *strep = str;
    unsigned ival;
    unsigned v = 0;
    unsigned exp = 1;

    // Move to end.
    while (strep[1])
        strep++;

    do {
        ival=*(unsigned char*)strep;
        //ival = tolower(ival);
        if ((ival>='0') && (ival<='9')) {
            ival-='0';
        } else if ((ival>='a') && (ival<='f')) {
            ival-='a';
            ival+=10;
        } else if ((ival>='A') && (ival<='F')) {
            ival-='A';
            ival+=10;
        } else {
            //printstring("Out of bounds ");
            //printhex(ival);
            return -1;
        }
        if (ival>(base-1)) {
            //printstring("Out of base bounds ");
            //printhex(ival);
            return -1;
        }
        v += exp * ival;
        exp *= base;
        strep--;
    } while (strep>=str);
    *dest = v;
    return 0;
}

static int parseinteger(const char *str, unsigned *dest)
{
    int base = 10;
    if ((str[0]=='0') && (str[1]=='x')) {
        // Hex.
        base=16;
        str+=2;
    }
    *dest=0;
    if ( mystrtol(str, dest, base) < 0)
        return -1;
    return 0;
}

static void inspect(char **tokens, int ntok)
{
    unsigned address;
    volatile unsigned *aptr;

    if (ntok<2) {
        printstring("Invalid number of arguments\n");
    } else {
        printstring("Addr '");
        printstring(tokens[1]);
        printstring("'\n");
        if (parseinteger(tokens[1], &address)<0) {
            printstring("Invalid address '");
            printstring(tokens[1]);
            printstring("'\n");
        } else {
            printstring("0x");
            printhex(address);
            printstring(": ");
            aptr =(volatile unsigned*)address;
            printhex(*aptr);
            printstring("\n");
        }
    }
}

static void writedata(char **tokens, int ntok)
{
    unsigned address,data;
    volatile unsigned *aptr;

    if (ntok<3) {
        printstring("Invalid number of arguments\n");
    } else {
        if (parseinteger(tokens[1], &address)<0) {
            printstring("Invalid address '");
            printstring(tokens[1]);
            printstring("'\n");
            return;
        }
        if (parseinteger(tokens[2], &data)<0) {
            printstring("Invalid data '");
            printstring(tokens[2]);
            printstring("'\n");
            return;
        }

        printstring("0x");
        printhex(address);
        printstring(" <- ");
        printhex(data);
        aptr =(volatile unsigned*)address;
        *aptr = data;
        printstring(" : ");
        printhex(*aptr);
        printstring("\n");
    }
}
static void addmemorywatch(char **tokens, int ntok)
{
    unsigned address;

    if (ntok<2) {
        printstring("Invalid number of arguments\n");
    } else {
        if (parseinteger(tokens[1], &address)<0) {
            printstring("Invalid address '");
            printstring(tokens[1]);
            printstring("'\n");
        } else {
            printstring("Setting memory address match to 0x");
            printhex(address);
            printstring("\n");
            __trace_set_memmatch(address);
        }
    }
}


extern void __restart_from_irq() __attribute__((noreturn));
extern void __restart_app() __attribute__((noreturn));

static int interactive_line(char *line)
{
    char *tokens[8];

    if (line[0]=='\0')
        return 1;
    int ntok = split(line,tokens,8);
    if (ntok<0) {
        printstring("Invalid line\n");
        return 1;
    }
    if (strcmp(tokens[0],"x")==0) {
        inspect(tokens,ntok);
    } else if (strcmp(tokens[0],"w")==0) {
        writedata(tokens,ntok);
    } else if (strcmp(tokens[0],"c")==0) {
        return 0;
    } else if (strcmp(tokens[0],"t")==0) {
        dump_tracebuffer();
        dump_membuffer();
    } else if (strcmp(tokens[0],"mw")==0) {
        addmemorywatch(tokens,ntok);
    } else if (strcmp(tokens[0],"r")==0) {
        printstring("Restarting application (reset).");
        __restart_from_irq();
    } else if (strcmp(tokens[0],"ra")==0) {
        printstring("Restarting application.");
        __restart_app();
    } else{
        printstring("Invalid command ");
        printstring(tokens[0]);
        printstring("\n");
    }

    printstring("Ok\r\n");
    return 1;
}

static int interactive_process(char r)
{
    switch(r){
    case '\n':
    case '\r':
        line[lptr] = '\0';
        outbyte('\r');
        outbyte('\n');
        if (interactive_line(line)==0)
            return 0;
        lptr=0;
        break;
    case '\x08':
        if (lptr>0)
            lptr--;
        // Clear char
        outbyte('\x08');
        outbyte(' ');
        outbyte('\x08');
        break;
    default:
        if (r<' ' || r>127)
            break;

        if (lptr<sizeof(line)-1) {
            line[lptr++]=r;
            outbyte(r);
        }
        break;
    }
    return 1;
}

static void interactive()
{
    lptr=0;
    do {
        int r = inbyte();
        if (interactive_process(r)==0)
            return;
    } while (1);
}


