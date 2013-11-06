.text

.globl _start
_start:
        limr    0x80000000, r3    /* Load IO base address into r3 */
        limr    55, r6            /* 104MHz. Baud rate: 115200, 16x oversample, 
                                     gives 55 for baud divider */
        copy    r4, r3            /* r4 <- r3 */
        addi    4, r4             /* Add 4 for the UART control register. */
        stw     r6, (r4-4)        /* Store baud rate divider in UART control reg */
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
        limr    0x400000, r2      /* 0x400000 cycles */
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
.waitready:
        ldw     (r4), r1              /* Load the UART control register */
        and     r1, r5              /* Check if bit 1 is set (and with 2) */
        brine   .waitready          /* No, jump into wait ready, UART is still busy */
        nop
        ldb+    (r2), r1              /* Load a char from string (at r2) into r1, increment r2 */
        or      r1, r1              /* Is a null char ? */
        brine   .waitready          /* No, not a null char, jump ... */
        stw     r1, (r3)              /* But store it in UART transmit register (this is delay slot) */
        ret                         /* Return from subroutine and ... */
        limr  0, r1                 /* set r1 to zero (the subroutine return value (this is delay slot) */


.data
        .global xpto

xpto:	.word 4

        .global mystring

mystring:
        .string "Hello World!\r\n\0"  /* Our string! */
