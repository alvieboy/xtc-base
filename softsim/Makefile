CFLAGS=-O2 -g -Wall

OBJ = softsim.o \
	executor.o \
	decode.o \
	io.o \
	memory.o \
	alu_ops.o \
	cflow_ops.o \
	mem_ops.o \
	reg_ops.o \
	cpu.o


all: xtce

clean:
	rm -fv $(OBJ)
	rm -fv xtce

xtce: $(OBJ)
	$(CC) -o $@ $+
