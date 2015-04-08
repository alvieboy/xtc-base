.section ".vectors", "ax"

.globl _start
_start:
        limr 0x90000004, r2
        limr 51, r1
        //limr 42, r1 /* Baudrate divider */
        stw r1, (r2)

	// Test writing to user registers
              /*
        limr	-1,	r1
        wusr	r1,	r1
        limr	0,	r1
        rusr	r1,	r1
                */
        
        /* Wait for a while, so receiver syncs on next char */
/*

        limr	0x10000, r1
.waitstart:
        cmpi	0,	r1
        br.cne	.waitstart, r0
        addi 	-1,	r1
*/
        br	outbyte, r13
        limr	'B',	r1

	limr 'Z', r1
        stw.i r1, (r2-4)

        br	outbyte, r13
        limr	'o',	r1
        br	outbyte, r13
        limr	'o',	r1
        br	outbyte, r13
        limr	't',	r1

	/* Detect top-of-ram first. Start at 0x1000 */
        ldw	(r0),	r6

        br	outbyte, r13
        limr	'1',	r1

        stw	r0, (r0)

        br	outbyte, r13
        limr	'2',	r1



        limr	0x1000, r1
        limr 	0xa5a5a5a5, r2
.ramd1:	stw	r2, (r1)
	ldw	(r0), r3
        cmp	r2,	r3
        br.ceq	.ramd2,	r0
        nop
        cmpi	0x40000000, r1
        br.ceq	.ramerr, r0
        nop
        br	.ramd1,	r0
        add	r1,	r1
.ramerr:	
	/* RAM error */
        br	outbyte, r13
        limr	'E',	r1
.endless:
	br	.endless, r0	
	nop
        
.ramd2: /* We have now top-of-memory, subtract a word so we can set up stack */
	stw	r6,	(r0) // Restore old word@0
        addr	r1,	r10
	add.i	r1, 	r15, -4
        
        br	outbyte, r13
	limr 'M', r1


/*
        limr	_trapbegin, r1
        wspr	r1, tr
        nop
*/
        rspr	psr, r1
        nop
        or.i	r1, r1, 2
        wspr	r1, psr
        nop
        
        // Flush i-cache.
        br	__flush_icache, r13
        nop


#ifdef BOOTSDRAM
        jmp	r0,	r0
        nop
#endif

#if 1

        limr 	bootstr, r1
	br	.printromstring, r13
        nop

        /* Print memory size */
        br	asmprinthex, r13
        addr	r10,	r1
        
        limr 	bootstr2, r1
	br	.printromstring, r13
        nop


        sra.i	r10,	r1, 2
        limr   	0,	r2
        
$.memtest:
	/* r1 is memory size in words, r2 is pointer */
        addr	r1,	r3
        addr	r2,	r4
        sra.i	r2, 	r2,	2
$.memtestloop1:
	stw	r2, 	(r2)
        addi	4,	r2
	stw	r2, 	(r2)
        addi	4,	r2
	stw	r2, 	(r2)
        addi	4,	r2
	stw	r2, 	(r2)
        addi	-4,	r1
	cmpi	0,	r1
        br.cne	$.memtestloop1, r0
        addi	4,	r2
	//nop
        
       
        /* read back */
$.memtestloop2:
        ldw	(r4),	r2
        cmp	r4,	r2
        br.cne	.memoryerror,	r13
        addi	-1,	r3
        cmpi	0,	r3
        br.cne	$.memtestloop2, r0
        addi	4,	r4

        limr 	strok,	r1
        br	.printromstring, r13
        nop
        
#endif

	br	main, r13
        nop
.end:        
	br	.end, r0
        nop

.memoryerror:
	/* r4 is memory address, r2 is value read */
        addr	r13,	r12
        addr	r1,	r11

        limr	$.strmemerror, r1
        br	.printromstring, r13
        nop
        addr	r4,	r1
        br	asmprinthex,	r13
        nop
        limr	$.strsep1,	r1
        br	.printromstring, r13
        nop
        addr	r4,	r1
        br	asmprinthex,	r13
        nop
        br	.eloop1, r0
        nop


.memoryerror1:
	/* r2 is memory address, r5 is value read */
        addr	r1,	r11
        addr	r2,	r7
        
        limr	$.strmemerror, r1
        br	.printromstring, r13
        nop
        addr	r7,	r1
        br	asmprinthex,	r13
        nop
        limr	$.strsep1,	r1
        br	.printromstring, r13
        nop
        addr	r5,	r1
        br	asmprinthex,	r13
        nop
.eloop1:
        br	.eloop1, r0
        nop


.section ".rodata"
$.strmemerror:
	.string "Memory error at address "
$.strsep1:	
	.string " "
.text
asmprinthex:
        addr	r13,	r5
	addr	r1,	r4
        limr	7,	r7
$.loop1:
	srl.i	r4, 	r1,	28
        shl.i	r4,	r4,	4
        and.i	r1,	r1,	15
        addi	'0',	r1
        cmpi	'9',	r1
        addi.cugt 'A'-'9', r1
        br	outbyte,	r13 /* uses r1,r2,r3 */
        nop
        cmpi	0,	r7
        br.cne	$.loop1,	r0
        addi	-1, 	r7
        jmp	r5,	r0
        nop

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
	jmp r13, r0
	nop
$tmp1:
	.size	outbyte, ($tmp1)-outbyte

.globl __flush_dcache
.type	__flush_dcache, @function
__flush_dcache:
        limr	2, r1
        copw	0, 0, r1
        nop
        nop
        nop
$.waitflush:
        copr	0, 0, r1
        nop
        and.i	r1, r2, 2
        cmpi	0, r2
        br.cne	($.waitflush), r0
        nop
        jmp	r13, r0
        nop
.size __flush_dcache, . - __flush_dcache;

.globl __flush_icache
.type  __flush_icache,@function
__flush_icache:
        /* D-Cache flushed. Flush i-cache */
        limr	1, r1  
        copw	0, 0, r1
        nop
        nop
        nop
        nop
        jmp	r13,	r0
        nop
.size __flush_icache, . - __flush_icache

.globl __bootstrap_app
__bootstrap_app:
	jmp	r1, r0	
        nop


.align 4
.nocopy:
        /* Jump into main, but needs to be an absolute jump */
        
        limr 	main, r13
        jmp	r13, r0
        limr 	0, r1
.eloop:
 	br .eloop, r0
        nop

.globl abort
abort:
	br	abort, r0
        nop

.section ".rodata"
.globl bootstr
bootstr:
	.string "XThunderCore Boot Loader v0.1 (C) 2014 Alvaro Lopes\r\nTesting 0x"
bootstr2:
	.string " bytes of memory: "
strerror:
	.string "Failed\r\n"
strok:
	.string "passed\r\n"

.section ".trap0", "ax"
trapbase:
	br	irqhandler, r0
        nop
.text
irqhandler:
	wspr	r15, sr0
        nop
        /* limr	0x1000-4, r15 */
        limr 0x7FFFFC, r15
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

        /* call "C" IRQ handler. */
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
        
__local_handle_irq:
	/* Clear up registers. */
	/*ldw	(r1), r2
        addi	2,	r2
        stw	r2,	(r1) -tihs is only for swi*/
        addr	r0,r1
        addr	r0,r2
        addr	r0,r3
        addr	r0,r4
        addr	r0,r5
        addr	r0,r6
        addr	r0,r7
        addr	r0,r8
        addr	r0,r9
        addr	r0,r10
        addr	r0,r11
        jmp	r13,	r0
        addr	r0,r12
        
        
        
.globl	__psr
__psr:
	rspr	psr,r1
        nop
        jmp 	r13, r0
        nop
$.retimmed:
	jmp	r13,	r0
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

.globl __trace_config
__trace_config:
 	copw	0, 6, 	r1
        nop
	jmp	r13,	r0

.globl __trace_get_faddr
__trace_get_faddr:
	copr	0, 7, 	r1
        nop
	jmp	r13,	r0
        nop

.globl __trace_get_fflags
__trace_get_fflags:
	copr	0, 6, 	r1
        nop
	jmp	r13,	r0
        nop


.data
	$.value1:	.long 0x12345678
        $.value2:	.long 0x00000002

