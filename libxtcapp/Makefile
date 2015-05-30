TARGET?=xtc

CROSS=xtc-elf-

CC=$(CROSS)clang 
CXX=$(CROSS)clang++
AS=$(CROSS)as

CFLAGS= -ISD -ferror-limit=1 -DXTC \
-O2 -ffunction-sections -fdata-sections \
-I/usr/local/xtc/xtc-elf/include/ -Wall -Werror -Wno-attributes -Wno-unused-function

CXXFLAGS=$(CFLAGS)
		 
SDLIBOBJS= fatfs/ff.o

OBJ= entry.o $(SDLIBOBJS) zposix.o zfdevice.o irq.o print.o premain.o serial.o support.o \
ffwrap.o disk.o spi.o

all: libxtcapp.a

ASFLAGS=
#%.o:%.c
#	$(CC) $(CFLAGS) -emit-llvm  -c $+ -o $@.bc
#	# list-hybrid, list-ilp, list-burr, vliw-td
#	llc -pre-RA-sched=list-hybrid  -asm-verbose $@.bc -o $@.s -filetype asm
#	$(CROSS)as $@.s -o $@ 

#%.o:%.s
#	$(CROSS)as $+ -o $@

#%.o:%.S
#	$(CROSS)as $+ -o $@

libxtcapp.a: $(OBJ)
	$(CROSS)ar cru libxtcapp.a $+
	$(CROSS)ranlib libxtcapp.a

clean:
	@rm -f $(OBJ) $(NAME).elf $(NAME).bin
	