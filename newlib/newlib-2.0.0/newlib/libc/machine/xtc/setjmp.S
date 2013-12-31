.globl setjmp
.section .text
.align 2  
.type setjmp, @function
setjmp:
        stw r6, ( r1 + 4 )
        ret
	stw r5, ( r1 + 0 )
.size setjmp, . - setjmp
