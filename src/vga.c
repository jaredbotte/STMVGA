#include "vga.h"
#include "stm32f0xx.h"

/* PINOUT
 * HSYNC : PA1 | PA2
 * VSYNC : PB5 | PB0
 * CLK_INH (BLANKING) : PA0 | PB4
 */

/* Theory of operation
 * We will allow the user to provide up to 64 "tiles" per "scene"
 * (Theoretically we could have 256, but we may run out of memory before then)
 * A tile is 16px wide and 16px tall. We'll allow 4 colors/tile. This will take 64 Bytes to store.
 * 64 * 64 = 4096 Bytes to store all the tiles. They will likely be stored in the data segment (flash memory)
 * 64 * 256 = 16,384 Bytes to store all tiles. There is a possibility that this will fit in flash memory.
 *
 * The screen is therefore 25 * ~19 tiles. The bottom quarter of the bottom tile will get cut off.
 * There's a chance that I will make the screen 25 * 18 tiles and use the top as a status bar of sorts.
 * We'll need to store one byte per tile space to be able to recall what tile to use for the space.
 * 25 * 19 = 475 Bytes to store the background data. This will be stored in RAM because scrolling backgrounds will make this change.
 *
 * This is great for static images, but we'll need a way to have sprites on the screen.
 * We'll also need a way to offset tiles so that the background can scroll.
 *
 * Let's have two line buffers, and fill them during the horizontal blanking time.
 * This will be a challenge, but we can likely do this during nops.
 * Also, we have two lines to generate the next buffer since we're sending each horizontal line twice.
 */

void setup_vga_GPIO(){
    /* PINOUT
     * TIM2_OC1 : PA0  - AF2
     * TIM2_OC2 : PA1  - AF2
     * TIM2_OC3 : PA2  - AF2
     * TIM3_OC1 : PB4  - AF1
     * TIM3_OC2 : PB5  - AF1
     * TIM3_OC3 : PB0  - AF1
     * RED SHFT : PB1  - OUT
     * BLU SHFT : PB2  - OUT
     * GRN SHFT : PB3  - OUT
     * LD DATA  : PA12 - IN
     * DATA OUT : PC0 - PC16 - OUT
     */
    RCC -> APB2ENR |= RCC_APB2ENR_SYSCFGCOMPEN;
    RCC -> AHBENR |= RCC_AHBENR_GPIOAEN | RCC_AHBENR_GPIOBEN | RCC_AHBENR_GPIOCEN;
    GPIOA -> MODER |= GPIO_MODER_MODER0_1 | GPIO_MODER_MODER1_1 | GPIO_MODER_MODER2_1;
    GPIOB -> MODER |= GPIO_MODER_MODER0_1 | GPIO_MODER_MODER4_1 | GPIO_MODER_MODER5_1;
    GPIOA -> AFR[0] |= 2 << (0 * 4) | 2 << (1 * 4) | 2 << (2 * 4);
    GPIOB -> AFR[0] |= 1 << (0 * 4) | 1 << (4 * 4) | 1 << (5 * 4);

    GPIOC -> MODER |= GPIO_MODER_MODER0_0 | GPIO_MODER_MODER1_0 | GPIO_MODER_MODER2_0;
    GPIOC -> MODER |= GPIO_MODER_MODER3_0 | GPIO_MODER_MODER4_0 | GPIO_MODER_MODER5_0;
    GPIOC -> MODER |= GPIO_MODER_MODER6_0 | GPIO_MODER_MODER7_0 | GPIO_MODER_MODER8_0;
    GPIOC -> MODER |= GPIO_MODER_MODER9_0 | GPIO_MODER_MODER10_0 | GPIO_MODER_MODER11_0;
    GPIOC -> MODER |= GPIO_MODER_MODER12_0 | GPIO_MODER_MODER13_0 | GPIO_MODER_MODER14_0;
    GPIOC -> MODER |= GPIO_MODER_MODER15_0;

    GPIOC -> OSPEEDR |= GPIO_OSPEEDR_OSPEEDR0_0 | GPIO_OSPEEDR_OSPEEDR1_0 | GPIO_OSPEEDR_OSPEEDR2_0;
    GPIOC -> OSPEEDR |= GPIO_OSPEEDR_OSPEEDR3_0 | GPIO_OSPEEDR_OSPEEDR4_0 | GPIO_OSPEEDR_OSPEEDR5_0;
    GPIOC -> OSPEEDR |= GPIO_OSPEEDR_OSPEEDR6_0 | GPIO_OSPEEDR_OSPEEDR7_0 | GPIO_OSPEEDR_OSPEEDR8_0;
    GPIOC -> OSPEEDR |= GPIO_OSPEEDR_OSPEEDR9_0 | GPIO_OSPEEDR_OSPEEDR10_0 | GPIO_OSPEEDR_OSPEEDR11_0;
    GPIOC -> OSPEEDR |= GPIO_OSPEEDR_OSPEEDR12_0 | GPIO_OSPEEDR_OSPEEDR13_0 | GPIO_OSPEEDR_OSPEEDR14_0;
    GPIOC -> OSPEEDR |= GPIO_OSPEEDR_OSPEEDR15_0;


    GPIOB -> MODER |= GPIO_MODER_MODER1_0;
    GPIOB -> OSPEEDR |= GPIO_OSPEEDR_OSPEEDR1_0;
    GPIOB -> MODER |= GPIO_MODER_MODER2_0;
    GPIOB -> OSPEEDR |= GPIO_OSPEEDR_OSPEEDR2_0;
    GPIOB -> MODER |= GPIO_MODER_MODER3_0;
    GPIOB -> OSPEEDR |= GPIO_OSPEEDR_OSPEEDR3_0;
    GPIOB -> MODER |= GPIO_MODER_MODER9_0;
    GPIOB -> OSPEEDR |= GPIO_OSPEEDR_OSPEEDR9_0;
    GPIOB -> BSRR |= GPIO_BSRR_BS_9;

    // This is a debugging pin to ensure timing is okay.
    GPIOB -> MODER |= GPIO_MODER_MODER10_0;
    GPIOB -> OSPEEDR |= GPIO_OSPEEDR_OSPEEDR10_0;

    // No need to specify EXTI or Input mode since A/Input are default
    EXTI -> RTSR |= EXTI_RTSR_TR12;
    EXTI -> EMR |= EXTI_EMR_MR12;
}

void setup_vga_timers(){
    /* Plan and Numbers:
     * The overall plan is to synchronize the timers and cascade them appropriately
     *
     * TIM2 - 35.15625 kHz - 2048 ARR - Horizontal Sync
     * TIM3 - 56 Hz - 625 ARR (Triggered from TIM6) - Vertical Sync
     *
     * TIM2 and TIM3 both have 4 Compare channels that we can use
     */
    RCC -> APB1ENR |= RCC_APB1ENR_TIM2EN | RCC_APB1ENR_TIM3EN;
    // First we'll set up TIM2. It should be the master timer.
    // NOTE: we'll prescale TIM2 by 2 so that the clock in TIM2 is 36MHz,
    //      this way it matches the pixel clock.
    TIM2 -> CR1 &= ~TIM_CR1_CEN;
    TIM2 -> CR2 |= TIM_CR2_MMS_1; // Master mode update
    TIM2 -> SMCR |= TIM_SMCR_MSM; // Turn on master/slave mode
    // OC1 : 800    clock cycles : Start of blanking (make high) - PWM MODE 2
    // OC2 : 824    clock cycles : Start of sync (make low)      - PWM MODE 1
    // OC3 : 952    clock cycles : End of sync (make high)       - PWM MODE 2
    // HSYNC = OC2 | OC3
    // CLK_INH = OC1 (Clock Inhibit)
    TIM2 -> CCMR1 |= TIM_CCMR1_OC1M;
    TIM2 -> CCMR1 |= TIM_CCMR1_OC2M_1 | TIM_CCMR1_OC2M_2;
    TIM2 -> CCMR2 |= TIM_CCMR2_OC3M;
    TIM2 -> CCER |= TIM_CCER_CC1E | TIM_CCER_CC2E | TIM_CCER_CC3E;

    TIM2 -> PSC = 2 - 1; // This will give 36MHz timer
    TIM2 -> ARR = 1024 - 1; // One line
    TIM2 -> CCR1 = 800;
    TIM2 -> CCR2 = 824;
    TIM2 -> CCR3 = 896;

    TIM2 -> DIER |= TIM_DIER_CC3IE; // Generate interrupt on start of back porch
    NVIC -> ISER[0] = 1 << TIM2_IRQn;
    NVIC_SetPriority(TIM2_IRQn,1); // It needs to have a lower priority than TIM3


    TIM3 -> CR1 &= ~TIM_CR1_CEN;
    TIM3 -> SMCR |= TIM_SMCR_TS_0; // TIM2 is the external clock
    TIM3 -> SMCR |= TIM_SMCR_SMS; // Slave external clock mode
    // Output compare 1 : 600 lines : Start of blanking (make high)  - PWM MODE 2
    // Output compare 2 : 601 lines : Start of sync (make low)      - PWM MODE 1
    // Output compare 3 : 623 lines : End of sync (make high)       - PWM MODE 2
    // VSYNC = OC2 | OC3
    // CLK_INH = OC1
    TIM3 -> CCMR1 |= TIM_CCMR1_OC1M;
    TIM3 -> CCMR1 |= TIM_CCMR1_OC2M_1 | TIM_CCMR1_OC2M_2;
    TIM3 -> CCMR2 |= TIM_CCMR2_OC3M;
    TIM3 -> CCER |= TIM_CCER_CC1E | TIM_CCER_CC2E | TIM_CCER_CC3E;

    TIM3 -> ARR = 625 - 1;
    TIM3 -> CCR1 = 600;
    TIM3 -> CCR2 = 601;
    TIM3 -> CCR3 = 603;

    TIM3 -> DIER |= TIM_DIER_CC1IE;
    NVIC -> ISER[0] = 1 << TIM3_IRQn;
}

void start_timers(){
    TIM3 -> CR1 = TIM_CR1_CEN;
    TIM2 -> CR1 = TIM_CR1_CEN;
}

extern uint16_t tiles[]; // TODO: Create script to generate tiles!
extern uint32_t  palettes[]; // TODO: Create script to generate palettes!
extern uint8_t background[]; // TODO: Create script to generate this!
extern uint8_t attributes[]; // TODO: Create script to generate attributes!
extern uint16_t lineBufferA[];
extern uint16_t lineBufferB[];
extern uint16_t xpos;
extern uint16_t ypos;
extern uint16_t mappos;

uint16_t lineBufferC[75] = {0};

uint16_t lineBuffer[75] = {
        0xffff, 0x0000, 0x0000, // Red
        0x0000, 0xffff, 0x0000, // Green
        0x0000, 0x0000, 0xffff, // Blue
        0xffff, 0xffff, 0x0000, // Yellow
        0x0000, 0xffff, 0xffff, // Cyan
        0xffff, 0x0000, 0xffff, // Magenta
        0xffff, 0xffff, 0xffff, // White
        0x0000, 0x0000, 0x0000, // Black
        0xffff, 0x0000, 0x0000, // Red
        0x0000, 0xffff, 0x0000, // Green
        0x0000, 0x0000, 0xffff, // Blue
        0xffff, 0xffff, 0x0000, // Yellow
        0x0000, 0xffff, 0xffff, // Cyan
        0xffff, 0x0000, 0xffff, // Magenta
        0xffff, 0xffff, 0xffff, // White
        0x0000, 0x0000, 0x0000, // Black
        0xffff, 0x0000, 0x0000, // ...
        0x0000, 0xffff, 0x0000,
        0x0000, 0x0000, 0xffff,
        0xffff, 0xffff, 0x0000,
        0x0000, 0xffff, 0xffff,
        0xffff, 0x0000, 0xffff,
        0xffff, 0xffff, 0xffff,
        0x0000, 0x0000, 0x0000,
        0x9696, 0x5a5a, 0x2e2e,
        //0xffff, 0x0000, 0x0000 // Red
};

extern void sendBuffers(uint16_t* linebuf, uint16_t* nextlinebuf);
extern void generateFirstLine();
uint8_t it = 0;

void TIM2_IRQHandler(){
    // TODO: Trigger this interrupt later..
    TIM2 -> SR &= ~TIM_SR_CC3IF;
    switch(it){
        case 0:
            xpos = 0;
            sendBuffers(lineBufferA, lineBufferB);
            it++;
            break;
        case 1:
            sendBuffers(lineBufferA, lineBufferB);
            it++;
            break;
        case 2:
            sendBuffers(lineBufferA, lineBufferB);
            mappos = 0;
            ypos++;
            it++;
            break;
        case 3:
            xpos = 0;
            sendBuffers(lineBufferB, lineBufferA);
            it++;
            break;
        case 4:
            sendBuffers(lineBufferB, lineBufferA);
            it++;
            break;
        case 5:
            sendBuffers(lineBufferB, lineBufferA);
            it = 0;
            mappos = 0; // In reality, this may need to increment to start producing the next line.
            if(ypos == 15){
                ypos = 0;
            } else {
                ypos++;
            }
            break;
    }
    /* Problems:
     *      * Everything is using the first value in the background/attribute map...
     *      * We only seem to have 7 tiles vertically? Should see 12.5
     */
}

void TIM3_IRQHandler(){
    // This interrupt will get triggered at the end of each screen.
    // Specifically, as soon as the vertical blanking period starts
    // 2048 clock cycles per line. 25 lines in blanking area.
    // It must complete in < 51,200 clock cycles... We can do a lot of stuff here.
    TIM3 -> SR &= ~TIM_SR_CC1IF;
    it = 0;
    xpos = 0;
    ypos = 0;
}


void setup_vga(){
    setup_vga_GPIO();
    setup_vga_timers();
    generateFirstLine();
    mappos = 0;
    start_timers();
}
