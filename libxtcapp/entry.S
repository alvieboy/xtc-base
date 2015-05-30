.section ".vectors", "ax"

.globl _start
_start:
	addr	r15,	r12
 	limr 	_stack - 4, r15
        addr	r13,	r1
        br	printhex, r13
        nop
        br	outbyte, r13
        limr	'B', r1
        
        limr	trapbase, r1
        //wspr	r1, tr
        copw	0, 1, r1

        nop
        
/*	ldw.i	(r0+_warmboot), r14
        cmpi	0, r14
        br.ceq	$.cold, r0
        nop
        rspr	psr,	r1
        nop
        wspr	r1,	spsr
        nop
        br	irqhandler, r0
        nop
$.cold:
        limr	1, 	r14
	stw.i	r14, (r0+_warmboot)
*/        
        
        rspr	psr, r1
        nop
        or.i	r1, r1, 2
        wspr	r1, psr
        nop

        br	outbyte, r13
        limr	'O', r1
        
        /* Enable memory protection */
        /*
        limr	_erodata,	r1
        copw	0, 7, r1
        nop
        
        limr	3,	r1
        copw	0, 6, r1
        nop
        */
        br	outbyte, r13
        limr	'P', r1
        

	/* Clear BSS */

#if 1 //ndef NOCLEARBSS        
        limr	__bss_start, r1
        limr	__bss_end - 4, r2
.bssloop:
       // ldw	(r1), r4
        stw	r0, (r1)
        cmp	r1, r2
        br.cne	.bssloop, r0
        addi	4, r1

        br	outbyte, r13
        limr	'b', r1
#endif

        /* Call Ctors */
        
	br	_premain, r13
        nop
       
	br	main, r13
        nop
        swi
.end:        
	br	.end, r0
        nop
.globl printromstring
printromstring:
.printromstring:
        addr	r1, r8
.loop:
        ldb	(r8), r1
        cmpi	0, r1
        br.ceq	.printreturn,	r0
	addi	1, r8
        addr	r13, r6
        br	outbyte, r13
        nop
        addr	r6, r13
        br   	.loop, r0
        nop
.printreturn:
	jmp	r13, r0
        nop
        
        .globl	outbyte
	.align	4
	.type	outbyte,@function
outbyte:                                # @outbyte
        limr 0x90000000, r2
$BB1_1:   
	ldw.i (r2 + 4), r3
	and.i    r3, r3, 2
	cmpi 0, r3
	br.cne ($BB1_1), r0
	nop
	stw.i r1, (r2)
	/* Flush */
$.flush:
	ldw.i (r2 + 4), r3
	and.i    r3, r3, 4
	cmpi 0, r3
	br.cne ($.flush), r0
        nop
        
	jmp r13, r0
	nop
$tmp1:
	.size	outbyte, ($tmp1)-outbyte


.align 4
.nocopy:
        /* Jump into main, but needs to be an absolute jump */
        
        limr 	main, r13
        jmp	r13, r0
        limr 	0, r1
.eloop:
 	br .eloop, r0
        nop
/*
.globl abort
abort:
	swi
	br	abort, r0
        nop
*/
.section ".rodata"
.globl bootstr
bootstr:
	.string "XThunderCore Boot Loader v0.1 (C) 2014 Alvaro Lopes\r\nTesting memory: "
strerror:
	.string "Failed\r\n"
strok:
	.string "Passed\r\n"

.section ".trap0", "ax"
trapbase:
	br	irqhandler, r0
        nop

.section ".trap1", "ax"
trapbase1:
	br	irqhandler, r0
        nop

.section ".trap2", "ax"
trapbase2:
	br	irqhandler, r0
        nop

.section ".trap3", "ax"
trapbase3:
	br	irqhandler, r0
        nop

.section ".trap4", "ax"
trapbase4:
	br	irqhandler, r0
        nop

.section ".bss", ""
_irqstackstart:
	.fill	256,	4, 0
_irqstackend:

.text
irqhandler:
	wspr	r15, sr0
        nop
        limr	_irqstackend-4, r15
        /* Preload data line. */
        ldw	(r15), r0

        stw	r1, (r15)
        stw.i	r2, (r15-4)
        stw.i	r3, (r15-8)
        stw.i	r4, (r15-12)
        stw.i	r5, (r15-16)
        stw.i	r6, (r15-20)
        stw.i	r7, (r15-24)
        stw.i	r8, (r15-28)
        stw.i	r9, (r15-32)
        stw.i	r10, (r15-36)
        stw.i	r11, (r15-40)
        stw.i	r12, (r15-44)
        stw.i	r13, (r15-48)
        stw.i	r14, (r15-52)

        rspr	sr0,	r1
        nop
        stw.i	r1,  (r15-56)

        rspr	spsr,	r1
        nop
        stw.i	r1,  (r15-60)

        /* Save trap PC */
        rspr	tpc,	r1
        nop
        stw.i	r1,  (r15-64)

        add.i	r15, r1, -64
        addi	-68, r15
        
        br	handle_irq, r13
        nop
        
        addi	68, r15

        ldw.i	(r15-64), r1
        wspr	r1,	tpc
        nop
        
        ldw.i	(r15-60), r1
        wspr	r1,	spsr
        nop
        
        ldw.i	(r15-56), r1
        wspr	r1,	sr0
        nop
        
        ldw.i	(r15-52), r14
        ldw.i	(r15-48), r13
        ldw.i	(r15-44), r12
        ldw.i	(r15-40), r11
        ldw.i	(r15-36), r10
        ldw.i	(r15-32), r9
        ldw.i	(r15-28), r8
        ldw.i	(r15-24), r7
        ldw.i	(r15-20), r6
        ldw.i	(r15-16), r5
        ldw.i	(r15-12), r4
        ldw.i	(r15-8), r3
        ldw.i	(r15-4), r2
        ldw	(r15), r1

        rspr	sr0, r15 
        nop

	jmpe	r0,r0
        nop
        
.globl  __restart_from_irq
__restart_from_irq:	
        limr	0x80000000, r1

	wspr	r1,	tpc
        nop
        /* Clear memory protection. */
        
        limr	1, 	r14
	stw.i	r14, (r0+_warmboot)

        limr	-1,	r1
        copw	0,	7,	r1

        jmpe	r0, 	r0
        nop

.globl  __restart_app
__restart_app:	
        limr	0, r1

	wspr	r1,	tpc
        nop
        limr	3, r1
        wspr	r1,	spsr
	nop
        
        limr	0, 	r1
	stw.i	r1, (r0+_warmboot)
        
        limr	-1,	r1
        copw	0,	7,	r1

        jmpe	r0, 	r0
        nop
        
.globl	__psr
__psr:
	rspr	psr,r1
        nop
        jmp 	r13, r0
        nop
      
.globl __trace_get_counters
__trace_get_counters:
	copr	0, 8, 	r1
        nop
	jmp	r13,	r0
        nop

.globl __trace_get_memcounters
__trace_get_memcounters:
	copr	0, 5, 	r1
        nop
	jmp	r13,	r0
        nop

.globl __trace_set_counter
__trace_set_counter:
	copw	0, 8, 	r1
        nop
	jmp	r13,	r0
        nop

.globl __trace_set_memcounter
__trace_set_memcounter:
	copw	0, 5, 	r1
        nop
	jmp	r13,	r0
        nop

.globl __trace_get_pc
__trace_get_pc:
	copr	0, 9, 	r1
        nop
	jmp	r13,	r0
        nop

.globl __trace_get_lhs
__trace_get_lhs:
	copr	0, 10, 	r1
        nop
	jmp	r13,	r0
        nop

.globl __trace_get_rhs
__trace_get_rhs:
	copr	0, 11, 	r1
        nop
	jmp	r13,	r0
        nop

.globl __trace_get_opcode
__trace_get_opcode:
	copr	0, 12, 	r1
        nop
	jmp	r13,	r0
        nop

.globl __trace_get_mempc
__trace_get_mempc:
	copr	0, 13, 	r1
        nop
	jmp	r13,	r0
        nop      

.globl __trace_get_memaddr
__trace_get_memaddr:
	copr	0, 14, 	r1
        nop
	jmp	r13,	r0
        nop      

.globl __trace_set_memmatch
__trace_set_memmatch:
	copw	0, 14, 	r1
        nop
	jmp	r13,	r0
        nop      

.globl __trace_get_memdata
__trace_get_memdata:
	copr	0, 15, 	r1
        nop
	jmp	r13,	r0
        nop      
.data
.globl __dso_handle
       __dso_handle:	.long 0
	_warmboot:	.long 0
        