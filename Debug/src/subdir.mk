################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/main.c \
../src/music.c \
../src/setup.c \
../src/syscalls.c \
../src/system_stm32f0xx.c \
../src/test.c \
../src/vga.c 

OBJS += \
./src/main.o \
./src/music.o \
./src/setup.o \
./src/syscalls.o \
./src/system_stm32f0xx.o \
./src/test.o \
./src/vga.o 

C_DEPS += \
./src/main.d \
./src/music.d \
./src/setup.d \
./src/syscalls.d \
./src/system_stm32f0xx.d \
./src/test.d \
./src/vga.d 


# Each subdirectory must supply rules for building sources it contributes
src/%.o: ../src/%.c
	@echo 'Building file: $<'
	@echo 'Invoking: MCU GCC Compiler'
	@echo $(PWD)
	arm-none-eabi-gcc -mcpu=cortex-m0 -mthumb -mfloat-abi=soft -DSTM32 -DSTM32F0 -DSTM32F091RCTx -DDEBUG -DSTM32F091 -DUSE_STDPERIPH_DRIVER -I"/Users/jared/Documents/workspace/VGA/StdPeriph_Driver/inc" -I"/Users/jared/Documents/workspace/VGA/inc" -I"/Users/jared/Documents/workspace/VGA/CMSIS/device" -I"/Users/jared/Documents/workspace/VGA/CMSIS/core" -O0 -g3 -Wall -fmessage-length=0 -ffunction-sections -c -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


