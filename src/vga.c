#include "vga.h"
#include "stm32f0xx.h"

/* PINOUT
 * HSYNC : PA1 | PA2
 * VSYNC : PB5 | PB0
 * CLK_INH (BLANKING) : PA0 | PB4
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
     * GRN SHFT :
     * LD DATA  : PA12 - IN (*** NEEDS VOLTAGE DIVIDER ***)
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

    // No need to specify EXTI or Input mode since A/Input are default
    EXTI -> RTSR |= EXTI_RTSR_TR12;
    EXTI -> IMR |= EXTI_IMR_MR12;
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

    TIM2 -> DIER |= TIM_DIER_CC1IE;
    NVIC -> ISER[0] = 1 << TIM2_IRQn;

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

    TIM3 -> CR1 = TIM_CR1_CEN;
    TIM2 -> CR1 = TIM_CR1_CEN;
}

extern uint16_t image[];
uint16_t currX = 0;
uint16_t currY = 0;

void TIM2_IRQHandler(){
    // This interrupt will get triggered at the end of each line.
    // Specifically, as soon as the horizontal blanking period starts.
    // It must complete in < 448 clock cycles
    TIM2 -> SR &= ~TIM_SR_CC1IF;
    currX = 0;
    //if(++currY % 2 == 1)
    //    currX = 0;
}

void TIM3_IRQHandler(){
    // This interrupt will get triggered at the end of each screen.
    // Specifically, as soon as the vertical blanking period starts
    // 2048 clock cycles per line. 25 lines in blanking area.
    // It must complete in < 51,200 clock cycles... We can do a ton of stuff here.
    TIM3 -> SR &= ~TIM_SR_CC1IF;
    currY = 0;
    currX = 0;
}


void EXTI4_15_IRQHandler(){
    // This interrupt should get called every 16 Pixel clocks.
    // It signifies that it's time to put data in the FIFOs again.
    // It must complete in < 64 clock cycles
    EXTI -> PR |= EXTI_PR_PR12;
    // TODO: Convert this to assembly
    // TODO: Create python script to convert image to 400x300px 16R16G16B format
    // TODO: and store it in the flash memory. Access it here and maybe print to screen?
    // This currently only prints lines...
    /*// RED
    GPIOC -> ODR = 0x0267;
    GPIOB -> BSRR = GPIO_BSRR_BS_1;
    GPIOB -> BSRR = GPIO_BSRR_BR_1;
    // GREEN
    GPIOC -> ODR = 0x0267;
    GPIOB -> BSRR = GPIO_BSRR_BS_2;
    GPIOB -> BSRR = GPIO_BSRR_BR_2;
    // BLUE
    //GPIOC -> ODR = 0xaaaa;
    GPIOC -> ODR = 0x0267;
    GPIOB -> BSRR = GPIO_BSRR_BS_3;
    GPIOB -> BSRR = GPIO_BSRR_BR_3;
    */
    // Let's try an image...
    // TODO: This isn't running fast enough. Write in assembly.
    // TODO: Time this and see if it runs fast enough...
    // NOTE: According to ARM, it will take 16 CPU Cycles before the first instruction in this ISR can be run...
    asm volatile(
            "LDR r2, =0x2\n"
            "LDR r3, =0x20000\n"

            "LDRH r5, [%1, %0]\n"
            "STRH r5, [%2]\n"
            "STRH r2, [%3]\n"
            "ADD %0, #16\n"
            "LSL r2, #1\n"
            "STRH r3, [%3]\n"
            "LSL r3, #1\n"

            "LDRH r5, [%1, %0]\n"
            "STRH r5, [%2]\n"
            "STRH r2, [%3]\n"
            "ADD %0, #16\n"
            "LSL r2, #1\n"
            "STRH r3, [%3]\n"
            "LSL r3, #1\n"

            "LDRH r5, [%1, %0]\n"
            "STRH r5, [%2]\n"
            "STRH r2, [%3]\n"
            "ADD %0, #16\n"
            "STRH r3, [%3]\n"

            : "+l"(currX) : "r"(image), "r"(GPIOC -> ODR), "r"(GPIOB -> BSRR): "r2", "r3", "r5", "cc");
    //GPIOC -> ODR = image[currX++];
    //GPIOB -> BSRR = GPIO_BSRR_BS_1;
    //GPIOB -> BSRR = GPIO_BSRR_BR_1;
    //GPIOC -> ODR = image[currX++];
    //GPIOB -> BSRR = GPIO_BSRR_BS_2;
    //GPIOB -> BSRR = GPIO_BSRR_BR_2;
    //GPIOC -> ODR = image[currX++];
    //GPIOB -> BSRR = GPIO_BSRR_BS_3;
    //GPIOB -> BSRR = GPIO_BSRR_BR_3;
}


void setup_vga(){
    setup_vga_GPIO();
    setup_vga_timers();
    NVIC -> ISER[0] = 1 << EXTI4_15_IRQn;
}
