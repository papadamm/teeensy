# TEEENSY 
TEEENSY (Also known as super simple sample code) is a set of sample files for microcontrollers. Each script generates a binary from source code that allows control of a board-specific LED on the target.

The goal with this project is to share practical development information to allow quick deployment of code on a wide range of target systems.
Information ranges from shell script logic, cross toolchain options, assembly instructions, MCU register internals to JTAG debugger details. 


The following MCUs and CPU cores are currently included:
- Microchip atmega328p (AVR)
- Nordic nRF5832 (ARM Cortex-M4)
- STMicro stm32g21j6m6 (ARM Cortex-M0+)
- STMicro stm32f103c8t6 (ARM Cortex-M3)
- Atmel at91sam3x8e (ARM Cortex-M3)
- GigaDevice gd32vf103 (RISC-V RV32IMAC)
  

Each file is a self-contained shell script that includes:
- Information about the target board name, MCU name and CPU core
- Comments about which toolchain version that is known to work
- Some basic check to see if the toolchain seems to be working
- Actual assembly code that controls an on-board LED
- Sample build code that generates a binary for the target
- Comments about how to upload and program the generated code to the target
- Information about which version of the debugger/uploader that is known to work


The script is typically invoked like this:
```console
% CROSS_COMPILE=~/cross-avr/bin/avr- ./teeensy-seeeduino-nano-atmega328p.sh
:06000000259A2D9A00C0B4
:00000001FF
%
```

By default the generated code will turn on a board-specific LED. Some shell scripts takes an argument like "off" to allow generating code that also turns off the LED. The user may locally edit the script to keep generated object files and use objdump or similar to disassemble the generated code and manually compare it with the assembly code in the script to see that all is well. 

A toolchain needs to be provided by the user and should be passed to the script using CROSS_COMPILE. Usually the toolchain is simply made up by a combo of GCC and Binutils. There is no external code linked in so the dependencies are minimal.

Whenever possible OpenOCD is used to control an external (or on-board) JTAG/SWD debugger to upload code to the target. This makes it possible to keep the same interface regardless of MCU vendor.

The script should work under any Unix system such as Linux and Mac OS X.

Anyone is welcome to contribute code, but please follow the requirements below:
- The target board needs to be a mass produced product. No custom boards.
- A software controllable on-board LED of some sort needs to be present.
- Ideally a SWD/JTAG debug port should be availale on the target board.
- A board specific upload method with open source host tools is also acceptable.

Feel free to copy-paste the sample code and use it whichever way you find fit.
