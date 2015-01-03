#include "zfdevice.h"
#include <string.h>

#define ZF_MAX_BACKENDS 8
#define ZF_MAX_DEVICES 32

struct zfbackend {
    char name[16];
    struct zfops *ops;
};

struct zfdevice {
    char name[16];
    struct zfdevops *ops;
    void *data;
};

static int __dev_initialized = 0;

static struct zfbackend __backends[ZF_MAX_BACKENDS];
static struct zfdevice __devices[ZF_MAX_DEVICES];

int zfRegisterFileBackend(const char *name, struct zfops *ops)
{
    int i;
    for (i=0;i<ZF_MAX_BACKENDS;i++) {
        if (__backends[i].ops==NULL) {
            __backends[i].ops = ops;
            strncpy(__backends[i].name,name,15);
            return 0;
        }
    }
    return -1;
}
struct zfops *zfFindBackend(const char *name)
{
    int i;
    for (i=0;i<ZF_MAX_BACKENDS;i++) {
        if (__backends[i].ops!=NULL) {
            if (strncmp(__backends[i].name,name,15)==0)
                return __backends[i].ops;
        }
    }
    return NULL;
}

static struct zfdevice *zfFindDevice(const char *name)
{
    int i;
    for (i=0;i<ZF_MAX_DEVICES;i++) {
        if (__devices[i].ops!=NULL) {
            if (strncmp(__devices[i].name,name,15)==0)
                return &__devices[i];
        }
    }
    return NULL;
}

static void *zf_dev_open(const char *path)
{
    struct zfdevice *dev = zfFindDevice(path);
    return dev;
}

static void zf_dev_close(void *handle)
{
}

static ssize_t zf_dev_read(void *handle,void *dest,size_t size)
{
    struct zfdevice *dev = (struct zfdevice*)handle;

    return dev->ops->read(dev->data,dest,size);
}

static ssize_t zf_dev_write(void *handle,const void *src,size_t size)
{
    struct zfdevice *dev = (struct zfdevice*)handle;

    return dev->ops->write(dev->data, src, size);
}

static ssize_t zf_dev_fstat(void *handle,struct stat *buf)
{
    return -1;
}
static ssize_t zf_dev_seek(void *handle,int pos, int whence)
{
    return -1;
}

static struct zfops dev_ops = {
    &zf_dev_open,
    &zf_dev_close,
    &zf_dev_read,
    &zf_dev_write,
    &zf_dev_seek,
    &zf_dev_fstat
};

static int __zfIntializeDev()
{
    return zfRegisterFileBackend("dev", &dev_ops);
}

int zfRegisterDevice(const char *name, struct zfdevops *ops, void *data)
{
    int i;

    if (!__dev_initialized)
        if (__zfIntializeDev()!=0)
            return -1;
    __dev_initialized=1;

    for (i=0;i!=ZF_MAX_DEVICES;i++) {
        if (__devices[i].ops==NULL) {
            strncpy(__devices[i].name, name, sizeof(__devices[i].name));
            __devices[i].ops = ops;
            __devices[i].data = data;
            return 0;
        }
    }
    return -1;
}
