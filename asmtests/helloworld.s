.text

.globl _start
_start:
        call    tests, r0
        nop
        limr    0x80000000, r3    /* Load IO base address into r3 */
        limr    55, r6            /* 104MHz. Baud rate: 115200, 16x oversample, 
                                     gives 55 for baud divider */
        stw     r6, (r3+4)        /* Store baud rate divider in UART control reg */
.endless:
        limr    mystring, r2      /* Load mystring offset into r2 */
        call    putstring, r0     /* Call putstring */
        nop
        call    delay, r0         /* Delay a few clock cycles */
        nop
        bri     .endless          /* Repeat */
        nop
        
.global delay
delay:
        limr    0x40, r2      /* 0x400000 cycles */
.wait:
        or      r2, r2            /* is r2 zero ? */
        brine   .wait             /* No, jump into .wait ... */
        addi    -1, r2            /* .. and decrement r2 (this is delay slot) */
        ret
        nop

.global putstring
.type putstring, @function
putstring:
        limr    2, r5               /* Load 2 into r5 */
        limr	0, r4		    /* Clear r4 - TODO: use XOR*/
.waitready:
        ldw     (r3+4), r1              /* Load the UART control register */
        and     r1, r5              /* Check if bit 1 is set (and with 2) */
        brine   .waitready          /* No, jump into wait ready, UART is still busy */
        nop
        ldb+    (r2), r1            /* Load a char from string (at r2) into r1, increment r2 */
        or      r1, r1              /* Is a null char ? */
        brieq   .end		    /* Yes, a null char, jump ... */
        nop
        stw     r1, (r3)            /* Store it in UART transmit register */
        bri	.waitready
        addi	1, r4               /* One more byte */
        
.end:   ret                         /* Return from subroutine and ... */
        copy    r1, r4              /* Copy */

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
    ret
    nop
.data
        .global xpto

xpto:	.word 4

        .global mystring

mystring:
        .string "Hello World!\r\n\0"  /* Our string! */
