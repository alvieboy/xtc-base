.text

.globl _start
_start:
	addr	r1, r2
        addr	r3, r4
        br	_start, r0
        nop
        br	_end, r0
        nop
_end: