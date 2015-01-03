/*
 Posix-like utility functions
 */
#include "zposix.h"
#include <sys/types.h>
#include <stdarg.h>
#include <ctype.h>
#include <sys/errno.h>
#include <time.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>
#include <stdio.h>

#include "zfdevice.h"

struct __filedes {
    //int backend_type;
    struct zfops *ops;
    void *data;
    int mode;
};

#ifdef __cplusplus__
extern "C" {
#endif

static struct __filedes __fds[MAX_FILES];
static char __cwd[128];

char *getcwd(char *buf, size_t size)
{
    return strncpy(buf,__cwd, size);
}

static char *makefullpath(char *dest, const char *pathname)
{
    char *d = dest;
    char cwd[128];

    if (pathname[0] == '/') {
        /* Full path */
        strcpy(dest,pathname);
    } else {
        getcwd(cwd, sizeof(cwd));
        size_t len = strlen(cwd);
        strcpy(d,cwd);
        d+=len;
        // CWD never ends with '/', except if we are on root.
        if (len!=1) {
            *d++='/';
            *d='\0';
        }
        strcat(d,pathname);
    }
    return dest;
}


int chdir(const char *path)
{
    if (path[0]=='/') {
        strcpy(__cwd, path);
    } else {
        if (strlen(__cwd)==1) {
            /* Root */
            strcat(__cwd, path);
        } else {
            strcat(__cwd,"/");
            strcat(__cwd, path);
        }
    }
    // Strip last "/" if present.
    size_t len = strlen(__cwd);
    while (len>0 && __cwd[len]=='/') {
        __cwd[len--]='\0';
    }
    return 0;
}

void debugprint(const char *c)
{
    volatile unsigned int *ptr = (volatile unsigned int*)0x90000000;
    while (*c) {
        while ((*(ptr+1)&0x2)!=0);
        *ptr = *c;
        c++;
    };
}

#define BACKEND_PRINT 1

/* Raw file I/O */

int open(const char *pathname, int flags,...)
{
    char rdevice[16];
    char path[128];
    char *pptr;
    int newfd=-1;
    int i;

    for (i=0;i!=MAX_FILES;i++) {
        if (__fds[i].ops == NULL) {
            newfd=i;
            break;
        }
    }

    if (newfd==-1)
        return newfd;

    __fds[newfd].mode = flags;

    if ((pathname==NULL) || (pathname[0]=='\0'))
        return -1;

    makefullpath(path, pathname);
    debugprint("open ");
    debugprint(pathname);
    debugprint("\r\n");
    debugprint(path);

    if (path[0]!='/') {
        debugprint("ai1");
        return -1;
    }
    debugprint("Lookup delim");

    pptr=&path[1];

    const char *delim = strchr(pptr,'/');

    debugprint("chr");

    if (NULL==delim) {
        debugprint("delim ");
        debugprint(pptr);
        return -1;
    } else {
        if (!*delim) {
            debugprint("ai3");

            return -1;
        }

        if ((delim-pptr) > 15) {
            debugprint("ai4");

            return -1; /* Too large */
        }

        strncpy(rdevice, pptr, delim-pptr);
        rdevice[delim-pptr] = '\0';

        delim++;
    }


    /* Look it up */
    debugprint("Find\r\n");
    struct zfops *ops = zfFindBackend(rdevice);

    if (ops==NULL) {
        debugprint("ai5 ");
        debugprint(rdevice);

        return -1;
    }

    debugprint("Call\r\n");
    debugprint(delim);
    void *handle = ops->open(delim);

    if (NULL==handle) {
        debugprint("No handle\r\n");

        return -1;
    }

    __fds[newfd].ops = ops;
    __fds[newfd].data = handle;

    return newfd;
}

int close(int fd)
{
    int ret = 0;
    if (__fds[fd].ops) {
        if (__fds[fd].ops->close) {
            __fds[fd].ops->close(__fds[fd].data);
        }
        __fds[fd].ops = NULL;
    }
    return ret;
}

ssize_t read(int fd, void *buf, size_t count)
{
    int ret = -1;
    if (__fds[fd].ops) {
        if (__fds[fd].ops->read) {
            ret = __fds[fd].ops->read(__fds[fd].data,buf,count);
        }
    }
    return ret;

}

int fstat(int fd, struct stat *buf)
{
    int ret = -1;
    if (__fds[fd].ops) {
        if (__fds[fd].ops->read) {
            ret = __fds[fd].ops->fstat(__fds[fd].data,buf);
        }
    }
    return ret;
}

ssize_t write(int fd, const void *buf, size_t count)
{
    int ret = -1;
    if (__fds[fd].ops) {
        if (__fds[fd].ops->write) {
            ret = __fds[fd].ops->write(__fds[fd].data,buf,count);
        }
    }
    return ret;
}
#if 0
void abort()
{
    while(1);
}
#endif

char *strerror(int err)
{
    return "Unknown";
}


off_t lseek(int fd, off_t offset, int whence)
{
    int ret = -1;
    if (__fds[fd].ops) {
        if (__fds[fd].ops->seek) {
            ret = __fds[fd].ops->seek(__fds[fd].data,offset,whence);
        }
    }
    return ret;
}

struct tm dummytm;

struct tm *gmtime(const time_t *timep)
{
    return &dummytm;
}

extern int _end;
static void *mend = 0;

void __attribute__((constructor)) __posix_init()
{
    static int initialized=0;
    int i;

    if (initialized)
        return;
    for (i=0;i!=MAX_FILES;i++) {
        __fds[i].ops=NULL;
    }
    __cwd[0]='/';
    __cwd[1]='\0';
    initialized=1;
}

int access(const char *pathname, int mode)
{
    return 0;
}
extern void outbyte();
static void printhex(unsigned int v)
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

#define PAGESIZE 4096
static int __brk_initialised=0;

static void brk__initialise()
{
    unsigned ptr = (unsigned)&_end;
    ptr+=(PAGESIZE-1);
    ptr&=~(PAGESIZE-1);

    mend = (void*)ptr;

    __brk_initialised=1;
}

void *sbrk(ptrdiff_t increment)
{
    if (!__brk_initialised)
        brk__initialise();

    void *ret = (void*)mend;

    increment += (PAGESIZE-1);
    increment &= (~(PAGESIZE-1));

    mend=(void*)((unsigned char*)mend + increment);
#ifdef DEBUG_SBRK

    outbyte('S');
    outbyte('B');
    outbyte('R');
    outbyte('K');
    outbyte(' ');
    printhex((unsigned)increment);
    outbyte(' ');
    printhex((unsigned)ret);
    outbyte('\n');
#endif
    return ret;
}

void _exit(int retval)
{
    abort();
}

extern unsigned int millis();
int gettimeofday(struct timeval *tv, void *tz)
{
    unsigned long now = millis();
    tv->tv_sec= now / 1000;
    tv->tv_usec = (now%1000)*1000;
    return 0;
}

int usleep(useconds_t usec)
{
    unsigned int start = millis();
    unsigned int end =  start + (usec/1000);
    if (start>end) {
        while (millis()>end) {

        }
    } else
        while (millis()<end) {

        }
    return 0;
}

int isatty(int fd)
{
    return 0;
}
