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
	nop
.endm

.macro SEND_PIXELS
	LDRH r3, [r0]			// 2
	STRH r3, [r2, #ODR]		// 4
	MOVS r3, #2				// 5
	STRH r3, [r1, #BSRR]	// 7
	ADDS r0, #2 			// 8
	STRH r3, [r1, #BRR]		// 10

	LDRH r3, [r0]			// 12
	STRH r3, [r2, #ODR]		// 14
	MOVS r3, #4				// 15
	STRH r3, [r1, #BSRR]	// 17
	ADDS r0, #2				// 18
	STRH r3, [r1, #BRR]		// 20

	LDRH r3, [r0]			// 22
	STRH r3, [r2, #ODR]		// 24
	MOVS r3, #8				// 25
	STRH r3, [r1, #BSRR]	// 27
	ADDS r0, #2				// 28
	STRH r3, [r1, #BRR]		// 30
.endm

// I'd really like this to finish in under 105 cycles.
// The maximum it can take is probably about 125-140.
// Beyond that, we'll have timing problems.

// TO USE PALETTE:
	// The attribute for the given background tile specifies the palette to use
	// R6 & R7   uses color 3
	// R6 & ~R7  uses color 2
	// R7 & ~R6  uses color 1
	// ~(R6 | R7) uses color 0

.macro GEN_NEXT_TILE
	MOV r4, r8 // r4 is the offset in the background map/attribute table. C:1
	LDR r3, =background // C:3
	LDRB r3, [r3, r4] // r3 is now the background info, which is just the tile offset. C:5
	LSLS r3, #2 // Multiply by four to get x offset C:6
	ADD r3, r9 // Add y offset C:7
	LDR r5, =tiles // C:9
	LDRH r6, [r5, r3] // This gets the MSBs of the specified tile. C:11
	ADDS r3, #2 // C:12
	LDRH r7, [r5, r3] // This gets the LSBs of the specified tile. C:14
	LDR r5, =attributes // C:16
	LDRB r5, [r5, r4] // C:18

	ADDS r4, #1
	MOV r8, r4

	LSLS r5, #2 // This will get us the palette offset. C:19
	LDR r3, =palettes // C:21
	LDR r4, [r3, r5] // r4 is now the pallete. C:23
	MOVS r5, r6 // C:24
	ORRS r5, r7 // C:25
	MVNS r5, r5 // r5 is now the color 0 mask. C:26
	ASRS r3, r4, #32 // C:27
	ANDS r3, r5 // C:28
	MOV r10, r3 // color 0 red done. C:29
	LSLS r4, #1 // C:30
	ASRS r3, r4, #32 // C:31
	ANDS r3, r5 // C:32
	MOV r11, r3 // color 0 green done. C:33
	LSLS r4, #1 // C:34
	ASRS r3, r4, #32 // C:35
	ANDS r3, r5 // C:36
	MOV r12, r3 // color 0  blue done. C:37
	MOVS r5, r7 // C:38
	BICS r5, r6 // r5 is now color 1 mask. C:39
	LSLS r4, #1 // C:40
	ASRS r3, r4, #32 // C:41
	ANDS r3, r5 // C:42
	MOV r2, r10 // C:43
	ORRS r2, r3 // C:44
	MOV r10, r2 // color 1 red done. C:45
	LSLS r4, #1 // C:46
	ASRS r3, r4, #32 // C:47
	ANDS r3, r5 // C:48
	MOV r2, r11 // C:49
	ORRS r2, r3 // C:50
	MOV r11, r2 // color 1 green done. C:51
	LSLS r4, #1 // C:52
	ASRS r3, r4, #32 // C:53
	ANDS r3, r5 // C:54
	MOV r2, r12 // C:55
	ORRS r2, r3 // C:56
	MOV r12, r2 // color 1 blue done. C:57
	MOVS r5, r6 // C:58
	BICS r5, r7 // r5 is now color 2 mask. C:59
	LSLS r4, #1 // C:60
	ASRS r3, r4, #32 // C:61
	ANDS r3, r5 // C:62
	MOV r2, r10 // C:63
	ORRS r2, r3 // C:64
	MOV r10, r2 // color 2 red done. C:65
	LSLS r4, #1 // C:66
	ASRS r3, r4, #32 // C:67
	ANDS r3, r5 // C:68
	MOV r2, r11 // C:69
	ORRS r2, r3 // C:70
	MOV r11, r2 // color 2 green done. C:71
	LSLS r4, #1 // C:72
	ASRS r3, r4, #32 // C:73
	ANDS r3, r5 // C:74
	MOV r5, r12 // C:75
	ORRS r5, r3 // color 2 blue done. Stored in r5. C:76
	ANDS r6, r7 // r6 is now color 3 mask. C:77
	LSLS r4, #1 // C:78
	ASRS r3, r4, #32 // C:79
	ANDS r3, r6 // C:80
	MOV r7, r10 // C:81
	ORRS r7, r3 // color 3 red done. Final red stored in r7. C:82
	LSLS r4, #1 // C:83
	ASRS r3, r4, #32 // C:84
	ANDS r3, r6 // C:85
	MOV r2, r11 // C:86
	ORRS r2, r3 // color 3 green done. Final green stored in r2. C:87
	LSLS r4, #1 // C:88
	ASRS r3, r4, #32 // C:89
	ANDS r3, r6 // C:90
	ORRS r5, r3 // color 3 blue done. Final blue stored in r5. C:91
	LDR r4, =nextLineBuffer // C:93
	LDR r4, [r4] // C:95
	LDR r6, =xpos // C:97
	LDRH r3, [r6] // C:99
	STRH r7, [r4, r3] // C:101
	ADDS r3, #2 // C:102
	STRH r2, [r4, r3] // C:104
	ADDS r3, #2 // C:105
	STRH r5, [r4, r3] // C:107
	ADDS r3, #2 // C:108
	STRH r3, [r6] // C:110
.endm

.data
.global lineBufferA
lineBufferA: .space 150
.global lineBufferB
lineBufferB: .space 150
nextLineBuffer: .word 0
.global ypos
ypos: .hword 0
.global xpos
xpos: .hword 0
.global mappos
mappos: .hword 0

.text
.equ ODR, 0x14
.equ BRR, 0x28
.equ BSRR, 0x18
.equ GPIOB, 0x48000400
.equ GPIOC, 0x48000800

.global sendBuffers
sendBuffers:
    // During this function we'll also try to generate the next line.
    // This will happen by using the background array in conjunction with the tiles and the palette.
    // TODO: Make sure the first line is sent to the shift regs ahead of time.
	// Let's assume that the linebuffer pointer is passed in (r0).
	// Also need to pass in the next linebuffer (r1)
	PUSH {r4, r5, r6, r7, lr}
	LDR r4, =nextLineBuffer
	STR r1, [r4] // The nextLineBuffer will be stored in the appropriate variable.

	LDR r4, =mappos
	LDRH r4, [r4]
	MOV r8, r4 // r8 is the mappos offset. Use this with background map.
	LDR r4, =ypos
	LDRH r4, [r4]
	MOVS r5, #0x10
	MULS r4, r5
	MOV r9, r4 // The Y offset will be stored here in r9.

	LDR r1, =GPIOB
	LDR r2, =GPIOC
	b skip0
	.LTORG
	skip0:
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	b skip1
	.LTORG
	skip1:
	// TODO: Tune here.
	//NOP_10 // Removing these things made the transition from tile 12->13 less fuzzy. Not sure why. May be able to use if needed.
	//NOP_10
	LDR r2, =GPIOC
	b skip2
	.LTORG
	skip2:
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	SEND_PIXELS
	GEN_NEXT_TILE
	b skip3
	.LTORG
	skip3:
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	FILL_TO_64
	FILL_TO_64

	LDR r5, =mappos
	MOV r4, r8
	STRH r4, [r5]
	nop
	nop
	nop
	nop
	nop
	// Might be able to add a few more instructions here...
	nop // This seems to be the maximum amount of instructions I can have before we start to miss our hard deadline.
	POP {r4, r5, r6, r7, pc}
	.LTORG

.global generateFirstLine
generateFirstLine:
	PUSH {r4-r7, LR}
	LDR r4, =nextLineBuffer
	LDR r3, =lineBufferA
	STR r3, [r4] // The nextLineBuffer will be stored in the appropriate variable.

	LDR r4, =mappos
	LDRH r4, [r4]
	MOV r8, r4 // r8 is the mappos offset. Use this with background map.
	LDR r4, =ypos
	LDRH r4, [r4]
	MOVS r5, #0x10
	MULS r4, r5
	MOV r9, r4 // The Y offset will be stored here in r9.

	GEN_NEXT_TILE
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	b skip7
	.LTORG
	skip7:
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	b skip8
	.LTORG
	skip8:
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	GEN_NEXT_TILE
    GEN_NEXT_TILE
	b skip9
	.LTORG
	skip9:
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	b skip10
	.LTORG
	skip10:
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	GEN_NEXT_TILE
	GEN_NEXT_TILE

	LDR r0, =ypos
	LDRH r1, [r0]
	ADDS r1, #1
	STRH r1, [r0]
	LDR r0, =mappos
	MOV r4, r8
	STRH r4, [r0]

	POP {r4-r7, PC}
