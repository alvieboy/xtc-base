#include "zfdevice.h"
#include <stdio.h>
#include <fcntl.h>
#include <string.h>

typedef volatile unsigned int *reg_t;

void serial_init(void *ptr)
{
  //  reg_t reg =(reg_t)ptr;
//    *(reg+1) = 42;//51;
}

static ssize_t serial_read(void *ptr, void *dest, size_t size)
{
    reg_t reg =(reg_t)ptr;
    return *reg;
}

static ssize_t serial_write(void *ptr, const void *src, size_t size)
{
    reg_t reg =(reg_t)ptr;
    size_t ret=size;
    unsigned char *sptr=(unsigned char*)src;
    while (size--) {
        while ((*(reg+1)&0x2)!=0);
        *reg = *sptr++;
    };
    return ret;
}


static struct zfdevops serial_devops = {
    &serial_read,
    &serial_write
};

extern void printstring(const char*);

void stdio_register_console(const char *device)
{
    if (NULL==fopen(device,"r")) {
        asm("swi");
        printstring("Cannot open STDIN?\n");
        while(1);
    }
    if (NULL==fopen(device,"w")) {
        asm("swi");
        printstring("Cannot open STDOUT?\n");
        while(1);
    }
    if (NULL==fopen(device,"w")) {
        asm("swi");
        printstring("Cannot open STDERR?\n");

        while(1);
    }
}

int serial_register_device(const char *name, void*data)
{
    char fname[32];
    char desc[64];
    serial_init(data);

    int r = zfRegisterDevice(name,&serial_devops, data);
    if (r==0) {
        sprintf(fname,"/dev/%s", name);
        sprintf(desc,"Registered console %s\r\n", fname);
        serial_devops.write(data, desc, strlen(desc));
        stdio_register_console(fname);
        sprintf(desc,"STDIO base registered in console %s\r\n", fname);
        serial_devops.write(data, desc, strlen(desc));
    }
    return r;
}