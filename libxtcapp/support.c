#include <string.h>

char *strchr(const char *s, int c)
{
    while (*s) {
        if ((*s)==c)
            return (char*)s;
        s++;
    }
    return NULL;
}

unsigned int millis()
{
    volatile unsigned int *uart = (volatile unsigned int*)0x90000000;
    return *(uart+3);
}

int kill(int pid, int sig)
{
    while (1);
}

int getpid()
{
    return 0;
}

unsigned int __mulsi3 (unsigned int a, unsigned int b)
{
    unsigned int r = 0;
    while (a)
    {
        if (a & 1)
            r += b;
        a >>= 1;
        b <<= 1;
    }
    return r;
}
