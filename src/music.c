#include "music.h"
//#include "step-array.h"
#include "stm32f0xx.h"

/* The goal of this file is to re-create basic 8-bit chiptune music
 * as a nice addition to out system. We will use step-array to define the notes
 * and try to keep all music code within this file. Music code should fit
 * within the front porch and take no longer than 48 clock cycles to complete.
 * Actually, let's try and keep it under 40 to allow time for context switching.
 *
 * I would like to base my music off of the C64 SID chip:
 * - 3 voices
 * - 4 forms of waves
 *  * sawtooth, triangle, rectangle (PWM), white noise
 *  * luckily, the STM32 has a white noise generator, and I can use a timer
 *    to generate PWM.
 *
 * It would be great if I could interpret SID files but that's a project for
 * another day...
 *
 */

void setup_music(){

}
