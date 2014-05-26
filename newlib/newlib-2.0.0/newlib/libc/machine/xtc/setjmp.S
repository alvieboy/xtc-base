.globl setjmp
.section .text
.align 2  
.type setjmp, @function
setjmp:
        stw.i r6, ( r1 + 4 )
        jmp	r13, r0
	stw r5, ( r1 )
.size setjmp, . - setjmp
