#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>

#include "cpu.h"
#include "opcodes.h"
#include "executor.h"


int run(const char *memfile)
{
    xtc_cpu_t *cpu = initialize();
    ssize_t read_size = 0;

    int fd = open(memfile,O_RDONLY);
    if (fd<0) {
        perror("Cannot open file");
        return -1;
    }

    read_size = read(fd,cpu->memory,cpu->memsize);
    if (read_size==-1) {
        perror("File could not open for reading");
        return -1;
    }

    execute(cpu);
    return 0;
}


int main(int argc, char **argv)
{
    return run(argv[1]);
}
