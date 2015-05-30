#include "print.h"

void printstring(const char *str)
{
    while (*str) {
        outbyte(*str++);
    }
}
void printhex(unsigned int v)
{
    unsigned int nibble;
    unsigned int count=8;
    while (count--) {
        nibble=v>>28;
        v<<=4;
        if (nibble>9)
            nibble+='A' - 10;
        else
            nibble+='0';
        outbyte(nibble);
    }
}
