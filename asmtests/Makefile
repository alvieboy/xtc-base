CROSS:=xtc-elf-

BIN=helloworld

AS=$(CROSS)as
LD=$(CROSS)ld
OBJCOPY=$(CROSS)objcopy
.PHONY: $(BIN).s

all: $(BIN).bin

$(BIN).elf: $(BIN).o
	$(LD) -N -relax -o $(BIN).elf $(BIN).o

$(BIN).bin: $(BIN).elf
	$(OBJCOPY) -O binary $(BIN).elf $(BIN).bin
	perl ../gen-prom-generic-dualport_32.pl  $(BIN).bin 32768 internalram > internalram.vhd
	#cp internalram.vhd ..
	@echo "internalram.vhd generated"
	