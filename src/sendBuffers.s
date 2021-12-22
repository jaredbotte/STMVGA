.cpu cortex-m0
.thumb
.syntax unified
.fpu softvfp

.macro NOP_10
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
.endm

.macro FILL_TO_64
	NOP_10
	NOP_10
	NOP_10
	nop
	nop
	nop
	nop
.endm

.macro ITERATION
	MOVS r4, #2 // 1

	LDRH r5, [r0, r3]		// 3
	STRH r5, [r2, #ODR]		// 5
	STRH r4, [r1, #BSRR]	// 7
	ADDS r3, #2 			// 8
	STRH r4, [r1, #BRR]		// 10
	LSLS r4, #1				// 11

	LDRH r5, [r0, r3]		// 13
	STRH r5, [r2, #ODR]		// 15
	STRH r4, [r1, #BSRR]	// 17
	ADDS r3, #2				// 18
	STRH r4, [r1, #BRR]		// 20
	LSLS r4, #1				// 21

	LDRH r5, [r0, r3]		// 23
	STRH r5, [r2, #ODR]		// 25
	STRH r4, [r1, #BSRR]	// 27
	ADDS r3, #2				// 28
	STRH r4, [r1, #BRR]		// 30

	//FILL_TO_64
.endm

.equ ODR, 0x14
.equ BRR, 0x28
.equ BSRR, 0x18

.text
.global sendBuffers
sendBuffers:
	// Let's assume that the linebuffer pointer is passed in (r0).
	// Also need to pass in GPIOB (r1) and GPIOC (r2)
	PUSH {r4, r5, lr}

	MOVS r3, #0

	// TODO: Remove these and have the interrupt get called later.
	FILL_TO_64
	FILL_TO_64
	FILL_TO_64
    FILL_TO_64
	FILL_TO_64

	ITERATION // 1
	FILL_TO_64
	ITERATION // 2
	FILL_TO_64
	ITERATION // 3
	FILL_TO_64
	ITERATION // 4
	FILL_TO_64
	ITERATION // 5
	FILL_TO_64
	ITERATION // 6
	FILL_TO_64
	ITERATION // 7
	FILL_TO_64
	ITERATION // 8
	FILL_TO_64
	ITERATION // 9
	FILL_TO_64
	ITERATION // 10
	FILL_TO_64
	ITERATION // 11
	FILL_TO_64
	ITERATION // 12
	FILL_TO_64
	ITERATION // 13
	FILL_TO_64
	ITERATION // 14
	FILL_TO_64
	ITERATION // 15
	FILL_TO_64
	ITERATION // 16
	FILL_TO_64
	ITERATION // 17
	FILL_TO_64
	ITERATION // 18
	FILL_TO_64
	ITERATION // 19
	FILL_TO_64
	ITERATION // 20
	FILL_TO_64
	ITERATION // 21
	FILL_TO_64
	ITERATION // 22
	FILL_TO_64
	ITERATION // 23
	FILL_TO_64
	ITERATION // 24
	FILL_TO_64
	ITERATION // 25

	POP {r4, r5, pc}
