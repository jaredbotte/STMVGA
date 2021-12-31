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

	// TODO: Remove these and have the interrupt get called later?
	FILL_TO_64
	FILL_TO_64
	FILL_TO_64
    FILL_TO_64
    // I'm going to replace one of the delay functions to instead load the higher registers.
	//FILL_TO_64
	// That gives me 35 cycles to burn.
	LDR r4, =nextLineBuffer // C:2
	STR r1, [r4] // The nextLineBuffer will be stored in the appropriate variable. C:4
	LDR r4, =xpos // C:6
	LDRH r4, [r4] // C:8
	MOV r8, r4 // r8 is the x offset. Use this with background map. C:10
	LDR r4, =ypos // C:12
	LDRH r4, [r4] // C:14
	MOVS r5, #0x10 // C:15
	MULS r4, r5 // C:16
	MOV r9, r4 // The Y offset will be stored here in r9. C:17
	nop // C:18
	nop // R10 will contain RED, C:19
	nop // R11 will contain BLUE, C:20
	nop // R12 will contain GREEN, C:21
	nop // C:22
	b skip0
	.LTORG
	skip0: // C:26
	LDR r1, =GPIOB // C:28
	LDR r2, =GPIOC // C:30
	nop
	nop
	nop
	MOVS r3, #0 // C:35

	// NOTE: Only r3-r7 can be used between iterations
	// NOTE: r1 and r2 can be used if they are set back to GPIOB and GPIOC respectively

	// NOTE: r4, r5, r6 and r7 are not touched by anything so use those to store critical data.

	// logical shift left followed by a signed shift right will allow me to get the value to AND with for each color.
	// this will either be all 1s if the color is used or all 0s if the color is not used.

	/*MOVS r4, #1
	LSLS r4, #9
	STRH r4, [r1, #BRR]
	STRH r4, [r1, #BSRR]*/

	// TODO: We have a FIFO with 16 Word depth. Let's take advantage of that and send the pixel
	// 		 data so that we have uninterrupted time to calculate the next set of pixels.

	SEND_PIXELS // Iteration 1
	// We get 35 cycles. Use them wisely.
	MOV r4, r8 // R4 is now the background map position, C: 1
	LDR r5, =background // C:3
	LDRB r5, [r5, r4] // This gets the offset number of the tile we want to use, C:5
	LSLS r5, #2 // Multiply by four to get the x offset, C:6
	ADD r5, r9 // Add the Y offset, C:7
	// TODO: Need to multiply to get tiles greater than 3? Maybe we'll change the memory map or the way that we address those tiles.
	LDR r3, =tiles // C:9
	LDRH r6, [r3, r5] // This gets the MSBs of the specified tile. C:11
	ADDS r5, #2 // C:12
	LDRH r7, [r3, r5] // This gets the LSBs of the specified tile. C:14
	LDR r5, =attributes // C:16
	LDRB r5, [r5, r4] // C:18
	LSLS r5, #2 // This will get us the palette offset. C:19
	LDR r3, =palettes // C:21
	LDR r4, [r3, r5] // r4 is now the pallete. C:23
	MOVS r5, r6 // C:24
	ORRS r5, r7 // C:25
	MVNS r5, r5 // r5 is the color 0 mask. C:26
	ASRS r3, r4, #32 // C:27
	ANDS r3, r5 // C:28
	MOV r10, r3 // Red color 0 done. C:29
	LSLS r4, #1 // C:30
	ASRS r3, r4, #32 // C:31
	ANDS r3, r5 // C:32
	MOV r11, r3 // Green color 0 done. C:33
	LSLS r4, #1 // C:34
	nop // C:35 Not sure there's anything I can do here.

	SEND_PIXELS // Iteration 2
	// Once again we have 35 cycles..
	ASRS r3, r4, #32 // C:1
	ANDS r3, r5 // C:2
	MOV r12, r3 // Blue color 0 done. C:3
	MOV r5, r7 // C:4
	BICS r5, r6 // r5 is now color 1 mask. C:5
	LSLS r4, #1 // C:6
	ASRS r3, r4, #32 // C:7
	ANDS r3, r5 // C:8
	MOV r2, r10 // C:9
	ORRS r2, r3 // C:10
	MOV r10, r2 // Red color 1 done. C:11
	LSLS r4, #1 // C:12
	ASRS r3, r4, #32 // C:13
	ANDS r3, r5 // C:14
	MOV r2, r11 // C:15
	ORRS r2, r3 // C:16
	MOV r11, r2 // Green color 1 done. C:17
	LSLS r4, #1 // C:18
	ASRS r3, r4, #32 // C:19
	ANDS r3, r5 // C:20
	MOV r2, r12 // C:21
	ORRS r2, r3 // C:22
	MOV r12, r2 // Blue color 1 done. C:23
	LSLS r4, #1 // C:24
	MOVS r5, r6 // C:25
	BICS r5, r7 // r5 is now color 2 mask. C:26
	ASRS r3, r4, #32 // C:27
	ANDS r3, r5 // C:27
	MOV r2, r10 // C:28
	ORRS r2, r3 // C:29
	MOV r10, r2 // Red color 2 done. C:30
	LSLS r4, #1 // C:31
	MOVS r3, #1 // C:32
	ADD r8, r3 // C:33
	LDR r2, =GPIOC // C:35

	SEND_PIXELS // Iteration 3
	ASRS r3, r4, #32 // C:1
	ANDS r3, r5 // C:2
	MOV r2, r11 // C:3
	ORRS r2, r3 // C:4
	MOV r11, r2 // Green color 2 done. C:5
	LSLS r4, #1 // C:6
	ASRS r3, r4, #32 // C:7
	ANDS r3, r5 // C:8
	MOV r2, r12 // C:9
	ORRS r2, r3 // C:10
	MOV r12, r2 // Blue color 2 done. C:11
	ANDS r6, r7 // r6 is now color 3 mask. Don't need to move to r5 because we'll need to reload for the next tile anyway. C:12
	LSLS r4, #1 // C:13
	ASRS r3, r4, #32 // C:14
	ANDS r3, r6 // C:15
	MOV r7, r10 // C:16
	ORRS r7, r3 // Red color 3 done. R7 is RED. C:17
	LSLS r4, #1 // C:18
	ASRS r3, r4, #32 // C:19
	ANDS r3, r6 // C:20
	MOV r5, r11 // C:21
	ORRS r5, r3 // Green color 3 done. R5 is GREEN. C:22
	LSLS r4, #1 // C:23
	ASRS r3, r4, #32 // C:24
	ANDS r3, r6 // C:25
	MOV r6, r12 // C:26
	ORRS r6, r3 // C:27 R6 is BLUE
	LDR r4, =nextLineBuffer // TODO: Need to send the right nextLineBuffer position when calling this function. C:29
	LDR r4, [r4] // C:31
	STRH r7, [r4] // C:33
	LDR r2, =GPIOC // C:35
	// At this point we're slightly over our deadline. This means we'll start eating into
	// the horizontal blanking period. Maybe we can somehow make this more efficient?
	// If not, about 33% of the horizontal blanking period will be lost to calculating the next frame.

	SEND_PIXELS // Iteration 4
	ADDS r4, #2 // C:1
	STRH r5, [r4] // C:3
	ADDS r4, #2 // C:4
	STRH r6, [r4] // C:6
	ADDS r4, #2 // C:7
	LDR r3, =nextLineBuffer // C:9
	STR r4, [r3] // Now the nextLineBuffer should point to the next spot to fill. C:11
	MOV r4, r8 // r4 is now the background map position. C:12
	LDR r5, =background // C:14
	LDRB r5, [r5, r4] // This gets the offset number of the tile we want to use, C:16
	LSLS r5, #2 // Multiply by four to get the x offset, C:17
	ADD r5, r9 // Add the Y offset, C:18
	LDR r3, =tiles // C:20
	LDRH r6, [r3, r5] // This gets the MSBs of the specified tile. C:22
	ADDS r5, #2 // C:23
	LDRH r7, [r3, r5] // This gets the LSBs of the specified tile. C:25
	LDR r5, =attributes // C:27
	LDRB r5, [r5, r4] // C:29
	LSLS r5, #2 // This will get us the palette offset. C:30
	LDR r3, =palettes // C:32
	LDR r4, [r3, r5] // r4 is now the pallete. C:34
	MOVS r5, r6 // C:35

	SEND_PIXELS // 5
	ORRS r5, r7 // C:1
	MVNS r5, r5 // r5 is the color 0 mask. C:2
	ASRS r3, r4, #32 // C:3
	ANDS r3, r5 // C:4
	MOV r10, r3 // Red color 0 done. C:5
	LSLS r4, #1 // C:6
	ASRS r3, r4, #32 // C:7
	ANDS r3, r5 // C:8
	MOV r11, r3 // Green color 0 done. C:9
	LSLS r4, #1 // C:10
	ASRS r3, r4, #32 // C:11
	ANDS r3, r5 // C:12
	MOV r12, r3 // Blue color 0 done. C:13
	MOV r5, r7 // C:14
	BICS r5, r6 // r5 is now color 1 mask. C:15
	LSLS r4, #1 // C:16
	ASRS r3, r4, #32 // C:17
	ANDS r3, r5 // C:18
	MOV r2, r10 // C:19
	ORRS r2, r3 // C:20
	MOV r10, r2 // Red color 1 done. C:21
	LSLS r4, #1 // C:22
	ASRS r3, r4, #32 // C:23
	ANDS r3, r5 // C:24
	MOV r2, r11 // C:25
	ORRS r2, r3 // C:26
	MOV r11, r2 // Green color 1 done. C:27
	LSLS r4, #1 // C:28
	ASRS r3, r4, #32 // C:29
	ANDS r3, r5 // C:30
	MOV r2, r12 // C:31
	ORRS r2, r3 // C:32
	MOV r12, r2 // Blue color 1 done. C:33
	LDR r2, =GPIOC // C:35

	SEND_PIXELS // 6
	LSLS r4, #1 // C:1
	MOVS r5, r6 // C:2
	BICS r5, r7 // r5 is now color 2 mask. C:3
	ASRS r3, r4, #32 // C:4
	ANDS r3, r5 // C:5
	MOV r2, r10 // C:6
	ORRS r2, r3 // C:7
	MOV r10, r2 // Red color 2 done. C:8
	LSLS r4, #1 // C:9
	MOVS r3, #1 // C:10
	ADD r8, r3 // C:11
	ASRS r3, r4, #32 // C:12
	ANDS r3, r5 // C:13
	MOV r2, r11 // C:14
	ORRS r2, r3 // C:15
	MOV r11, r2 // Green color 2 done. C:16
	LSLS r4, #1 // C:17
	ASRS r3, r4, #32 // C:18
	ANDS r3, r5 // C:19
	MOV r2, r12 // C:20
	ORRS r2, r3 // C:21
	MOV r12, r2 // Blue color 2 done. C:22
	ANDS r6, r7 // r6 is now color 3 mask. Don't need to move to r5 because we'll need to reload for the next tile anyway. C:23
	LSLS r4, #1 // C:24
	ASRS r3, r4, #32 // C:25
	ANDS r3, r6 // C:26
	MOV r7, r10 // C:27
	ORRS r7, r3 // Red color 3 done. R7 is RED. C:28
	LSLS r4, #1 // C:29
	ASRS r3, r4, #32 // C:30
	ANDS r3, r6 // C:31
	MOV r5, r11 // C:32
	ORRS r5, r3 // Green color 3 done. R5 is GREEN. C:33
	LDR r2, =GPIOC // C:35

	SEND_PIXELS // 7
	FILL_TO_64
	SEND_PIXELS // 8
	FILL_TO_64
	SEND_PIXELS // 9
	FILL_TO_64
	SEND_PIXELS // 10
	//FILL_TO_64
    b skip1
	.LTORG // TODO: Confirm that this has equivalent/acceptable delay.
	skip1:
	NOP_10
	NOP_10
	NOP_10
	SEND_PIXELS // 11
	FILL_TO_64
	SEND_PIXELS // 12
	FILL_TO_64
	SEND_PIXELS // 13
	FILL_TO_64
	SEND_PIXELS // 14
	FILL_TO_64
	SEND_PIXELS // 15
	FILL_TO_64
	SEND_PIXELS // 16
	FILL_TO_64
	SEND_PIXELS // 17
	FILL_TO_64
	SEND_PIXELS // 18
	FILL_TO_64
	SEND_PIXELS // 19
	FILL_TO_64
	SEND_PIXELS // 20
	FILL_TO_64
	SEND_PIXELS // 21
	FILL_TO_64
	SEND_PIXELS // 22
	FILL_TO_64
	SEND_PIXELS // 23
	FILL_TO_64
	SEND_PIXELS // 24
	FILL_TO_64
	SEND_PIXELS // 25

	POP {r4, r5, r6, r7, pc}
	.LTORG

.global generateFirstLine
generateFirstLine:
// TODO: rewrite this using newly learned stuff.
	PUSH {r4-r7, LR}
	loop:
	LDR r0, =xpos
	LDRH r0, [r0] // This should get the value at currLoc?

	LDR r1, =background
	LDR r2, =tiles
	LDR r3, =attributes
	LDR r4, =palettes

	LDRB r5, [r1, r0] // This gets the offset number of the first tile.
	LSLS r5, #2 // Multiply by four to get the offset.
	LDRH r6, [r2, r5] // This gets the MSBs of the specified tile.
	ADDS r5, #2
	LDRH r7, [r2, r5] // This gets the LSBs of the specified tile.

	// TO USE PALETTE:
	// The attribute for the given background tile specifies the palette to use
	// R6 & R7   uses color 3
	// R6 & ~R7  uses color 2
	// R7 & ~R6  uses color 1
	// ~(R6 | R7) uses color 0

	LDRB r5, [r3, r0] // This should get the attribute byte for the tile
	LSLS r5, #1
	LDRH r5, [r4, r5] // This should get the palette.

	// R1 - RED, R2 - GREEN, R3 - BLUE
	LDR r0, =0x800
	MOVS r1, #0
	MOVS r2, #0
	MOVS r3, #0
	MOVS r4, #0

	color0:
		ORRS r4, r6
		ORRS r4, r7
		MVNS r4, r4
	testRed0:
		TST r5, r0
		BEQ testGreen0
		ORRS r1, r4
	testGreen0:
		LSRS r0, #1
		TST r5, r0
		BEQ testBlue0
		ORRS r2, r4
	testBlue0:
		LSRS r0, #1
		TST r5, r0
		BEQ color1
		ORRS r3, r4
	color1:
		MOVS r4, r7
		BICS r4, r6
	testRed1:
		LSRS r0, #1
		TST r5, r0
		BEQ testGreen1
		ORRS r1, r4
	testGreen1:
		LSRS r0, #1
		TST r5, r0
		BEQ testBlue1
		ORRS r2, r4
	testBlue1:
		LSRS r0, #1
		TST r5, r0
		BEQ color2
		ORRS r3, r4
	color2:
		MOVS r4, r6
		BICS r4, r7
	testRed2:
		LSRS r0, #1
		TST r5, r0
		BEQ testGreen2
		ORRS r1, r4
	testGreen2:
		LSRS r0, #1
		TST r5, r0
		BEQ testBlue2
		ORRS r2, r4
	testBlue2:
		LSRS r0, #1
		TST r5, r0
		BEQ color3
		ORRS r3, r4
	color3:
		MOVS r4, r6
		ANDS r4, r7
	testRed3:
		LSRS r0, #1
		TST r5, r0
		BEQ testGreen3
		ORRS r1, r4
	testGreen3:
		LSRS r0, #1
		TST r5, r0
		BEQ testBlue3
		ORRS r2, r4
	testBlue3:
		LSRS r0, #1
		TST r5, r0
		BEQ storeall
		ORRS r3, r4
	storeall:
		LDR r0, =xpos
		LDRH r4, [r0]
		MOVS r5, #6
		MULS r5, r4 // This should get us the correct linebuffer location
		ADDS r4, #1
		STRH r4, [r0] // Store the current location.
		LDR r6, =lineBufferA
		STRH r1, [r6, r5]
		ADDS r5, #2
		STRH r2, [r6, r5]
		ADDS r5, #2
		STRH r3, [r6, r5]

	CMP r4, #25
	BLS loop

	LDR r0, =ypos
	LDRH r1, [r0]
	ADDS r1, #1
	STRH r1, [r0]
	POP {r4-r7, PC}
