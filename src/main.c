/**
  ******************************************************************************
  * @file    main.c
  * @author  Ac6
  * @version V1.0
  * @date    01-December-2013
  * @brief   Default main function.
  ******************************************************************************
*/


#include "stm32f0xx.h"
#include "setup.h"
#include "vga.h"

#define CLOCK_FREQ 72000000

/* MASTER PINOUT
 * These are all the pins currently being used and what they are being used for.
 * This should be referenced when choosing new pins for functions.
 * PA0  - TIM2_OC1 - H. Blanking (Clock Inhibit)
 * PA1  - TIM2_OC2 - H. Sync Start
 * PA2  - TIM2_OC3 - H. Sync End
 * PA4  - TODO     - Sound Generation
 * PA8  - MCO      - 18MHz (Direct from clock)
 * PA12 - LD START - FIFO Data loaded, new data needed
 * PB0  - TIM3_OC3 - V. Sync End
 * PB1  - RED SI   - RED FIFO Shift In Data
 * PB2  - GRN SI   - GREEN FIFO Shift In Data
 * PB3  - BLU SI   - BLUE FIFO Shift In Data
 * PB4  - TIM3_OC1 - V. Blanking (Clock Inhibit)
 * PB5  - TIM3_OC2 - V. Sync Start
 * PC0  |
 * ...  } - VIDEO DATA TO FIFOs
 * PC15 |
 *
 *  Still needed - FIFO SELECTION 3 GPIO
 */

int main(void)
{
    overclock_system();
    configure_GPIOA();
    setup_vga();
	for(;;){
	    asm("wfi");
	}
}

//  TODO: Add sound generation using DMA and TIM2 update to trigger DAC.
//        This gives us a sampling rate of 35.15625 kHz. Excellent!
