#include "zfdevice.h"
#include <string.h>
#include <unistd.h>

#define MAX_MEM_HANDLES 2

struct memhandle
{
    unsigned char name[32];
    unsigned char *start;
    unsigned int size;
    unsigned int pos; /* Current position */
};

static struct memhandle handles[MAX_MEM_HANDLES] = {{0}};

static int __backend_initialized=0;

static void *mem_open(const char *path)
{
    struct memhandle *handle;
    int i;

    for (i=0;i<MAX_MEM_HANDLES;i++) {
        if (handles[i].start==NULL)
            continue;

        if (strcmp(path, (const char*)handles[i].name)==0) {
            return &handles[i];
        }
    }
    return NULL;
}

static void mem_close(void *handle)
{

}

static ssize_t mem_read(void *handle,void *dest,size_t size)
{
    struct memhandle *h = (struct memhandle*)handle;
    int readsize = size;
    if (h->pos + size > h->size) {
        readsize = h->size - h->pos;
    }
    if (readsize==0)
        return readsize;
    memcpy(dest, &h->start[ h->pos ], readsize);
    h->pos += readsize;
    return readsize;
}

static ssize_t mem_write(void *handle,const void *src,size_t size)
{
    struct memhandle *h = (struct memhandle*)handle;
    return -1;
}

static ssize_t mem_fstat(void *handle,struct stat *buf)
{
    struct memhandle *h = (struct memhandle*)handle;

    buf->st_size = h->size;
    buf->st_blksize = 512; /* blocksize for file system I/O */

    return 0;
}
static ssize_t mem_seek(void *handle,int pos, int whence)
{
    struct memhandle *h = (struct memhandle*)handle;
    int newpos;

    switch(whence) {
    case SEEK_SET:
        newpos=pos;
        break;
    case SEEK_CUR:
        newpos = h->pos + pos;
    case SEEK_END:
        newpos = h->size + pos;
    }

    if (newpos<0)
        newpos=0;
    if (newpos>h->size)
        newpos=h->size;
    return newpos;
}

static struct zfops dev_ops = {
    &mem_open,
    &mem_close,
    &mem_read,
    &mem_write,
    &mem_seek,
    &mem_fstat
};

 int __memAddFile(const char *name, void *start, unsigned size)
{
    int i;
    int ret=-1;

    if (!__backend_initialized)
        if (zfRegisterFileBackend("mem", &dev_ops)<0)
            return ret;

    __backend_initialized=1;

    return 0;

    /* Find a free slot */

    for(i=0; i<MAX_MEM_HANDLES; i++) {
        if (handles[i].start==NULL) {
            strcpy( handles[i].name, name );
            handles[i].start = start;
            handles[i].size = size;
            handles[i].pos = 0;
            ret=0;
            break;
        }
    }
    return ret;

}
