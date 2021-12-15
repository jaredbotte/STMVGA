#include "setup.h"
#include "stm32f0xx.h"

void overclock_system(){
    // Check is PLL is being used as system clock
    if((RCC->CFGR & RCC_CFGR_SWS) == RCC_CFGR_SWS_PLL){
        // If it is, switch to HSI so we can modify PLL values
        RCC -> CFGR &= ~RCC_CFGR_SW;
        // Wait for switch to happen
        while((RCC->CFGR & RCC_CFGR_SWS) != RCC_CFGR_SWS_HSI);
    }

    //. Turn off PLL so we can modify it
    RCC -> CR &= ~RCC_CR_PLLON;
    // Wait until PLL is no longer ready
    while(RCC -> CR & RCC_CR_PLLRDY);

    RCC -> CFGR |= RCC_CFGR_MCO_PRE_2 | RCC_CFGR_MCO_PLL; // Configure MCO to PLL / 2 / 2 = PLL / 4 = 18MHz
    RCC -> CFGR |= RCC_CFGR_PLLMUL9 | RCC_CFGR_PLLSRC_HSE_PREDIV; // Configure PLL source and multiplier
    RCC -> CR |= RCC_CR_PLLON;

    while((RCC -> CR & RCC_CR_PLLRDY) == 0);
    RCC -> CFGR |= RCC_CFGR_SW_PLL;
    while((RCC -> CFGR & RCC_CFGR_SWS) != RCC_CFGR_SWS_PLL);
}

void configure_GPIOA(){
    // This should set the pin to output a signal that is 1/4 the clock speed.
    // With clock speed = 72MHz, we should see an 18MHz clock on PA8.
    RCC -> AHBENR |= RCC_AHBENR_GPIOAEN;
    GPIOA -> MODER |= GPIO_MODER_MODER8_1;
    GPIOA -> OSPEEDR |= GPIO_OSPEEDR_OSPEEDR8;
}
