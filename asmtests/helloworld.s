.text

.globl _start
_start:
	copr	0,3,r11
        br    tests, r13
        nop
        limr    0x80000000, r3    /* Load IO base address into r3 */
        limr    55, r6            /* 104MHz. Baud rate: 115200, 16x oversample, 
                                     gives 55 for baud divider */
        stw.i     r6, (r3+4)      /* Store baud rate divider in UART control reg */
.endless:
        limr    mystring, r2      /* Load mystring offset into r2 */
        br      putstring, r13     /* Call putstring */
        nop
        br    delay, r13         /* Delay a few clock cycles */
        nop
        br     .endless, r0          /* Repeat */
        nop
        
.global delay
delay:
        limr    0x40, r2      /* 0x400000 cycles */
.wait:
        or      r2, r2            /* is r2 zero ? */
        br.cne .wait, r0             /* No, jump into .wait ... */
        addi    -1, r2            /* .. and decrement r2 (this is delay slot) */
        jmp	r13, r0
        nop

.global putstring
.type putstring, @function
putstring:
        limr    2, r5               /* Load 2 into r5 */
        xor	r4, r4		    /* Clear r4 - TODO: use XOR*/
.waitready:
        ldw.i     (r3+4), r1              /* Load the UART control register */
        and       r5, r1              /* Check if bit 1 is set (and with 2) */
        br.cne .waitready, r0          /* No, jump into wait ready, UART is still busy */
        nop
        ldb     (r2), r1            /* Load a char from string (at r2) into r1, increment r2 */
        addi	1, r2
        or      r1, r1              /* Is a null char ? */
        br.ceq   .end, r0		    /* Yes, a null char, jump ... */
        nop
        stw     r1, (r3)            /* Store it in UART transmit register */
        br   .waitready, r0
        addi	1, r4               /* One more byte */
        
.end:   jmp 	r13, r0                 /* Return from subroutine and ... */
        addr    r1, r4              /* Copy */

.align 4
    tests:
    limr 0, r6
    limr 0, r7
    limr 1, r8
    limr 0, r9
    addi 1, r6
    add r7, r8
    addi 1, r9
    add r7, r8
    jmp	r13, r0
    nop
.data
        .global xpto

xpto:	.word 4

        .global mystring

mystring:
        .string "Hello World!\r\n\0"  /* Our string! */
