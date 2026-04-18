#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-generic-stm32f103c8t6.sh (also known as super simple sample code)
# generic code for "ARM STM32 Minimum System Development Board" stm32f103c8t6
# (sold on Amazon under HiLetgo and VKLSVAN brands) turn on PC13 LED
#
# Copyright (C) 2026 Magnus Damm
#
# this script builds some bundled tiny example code to generate a binary
# which may be used to test execution via a debugger on the target
# see further down in the file for some ARM assembly source code
#
# set CROSS_COMPILE to point out the toolchain
# gcc-arm-none-eabi-6-2017-q2-update is known to work

# makes use of a stm32f103c8t6 (with a Cortex-M3)
ARCH=armv7-m

# Probe for required software components
for e in cat grep mktemp rm wc which ${CROSS_COMPILE}gcc ${CROSS_COMPILE}as \
	     ${CROSS_COMPILE}ld ${CROSS_COMPILE}objdump
do
    if [ -z `which $e` ]; then
        echo "unable to detect required software component $e, exiting" >&2
        exit 1;
    fi
done

# Check that CROSS_COMPILE actually points to a cross compiler for ARM
if [[ `${CROSS_COMPILE}gcc -dumpspecs | grep ${ARCH} | wc -l` -eq 0 ]]; then
    echo "Failed to detect ARM support in CROSS_COMPILE, exiting" >&2
    exit 1;
fi

cleanup() {
    rm -f "${t0}" "${t1}" 2>/dev/null
}

trap cleanup EXIT
t0=$(mktemp)
t1=$(mktemp)
for e in "${t0}" "${t1}"
do
    if [ -z "${e}" ]; then
        echo "Failed to create temporary file, exiting" >&2
        exit 1;
    fi
done

# turn on break-on-failure
set -e

${CROSS_COMPILE}as -mlittle-endian -o "${t0}" <<EOF
  .syntax unified
  .arch ${ARCH}

  .arm
  .thumb
  .thumb_func
  .text
  .align 2
  .global vector_table
vector_table:
  .long 0 /* Top of stack set to nothing since unused */
  .long _start
  .space 126 * 4
	
  .align 1
  .global _start
  .type _start, %function
_start:
  /* setup RCC_APB2ENR to enable clocks to GPIO blocks */
  /* configure GPIOC_CRH (this turns on the LED) */
  /* optionally clear/set PC13 using GPIOC_BSRR to enable/disable LED */

  ldr r0, =0x1fc
  ldr r5, =0x40021018 /* RCC_APB2ENR */
  str r0, [r5]

  ldr r0, =0x44344444
  ldr r5, =0x40011004 /* GPIOC_CRH */
  str r0, [r5]

  /* ldr r0, =0x20000000 */
  /* ldr r5, =0x0x40011010 */ /* GPIOC_BSRR */
  /* str r0, [r5] */

  /* ldr r0, =0x2000 */
  /* ldr r5, =0x0x40011010 */ /* GPIOC_BSRR */
  /* str r0, [r5] */

end:
  b end

  .align 2
  .pool
EOF

${CROSS_COMPILE}ld --section-start=.text=0x08000000 "${t0}" -o "${t1}"
${CROSS_COMPILE}objcopy "${t1}" -O ihex "${t0}"
cat "${t0}" # the contents come out on stdout, used as "file.hex" below

# example using Segger J-Link Ultra connected to 4-pin SWD port
# openocd 0.12.0 is known to work
#
# openocd -f interface/jlink.cfg -c "transport select swd" \
#	-f target/stm32f1x.cfg
# telnet localhost 4444

# (erase the flash on the board which causes the LED to be off at power on)
# halt
# flash erase_sector 0 0 last
# reset halt
# resume

# (program the above software which will make the LED light up at power on)
# halt
# program file.hex
# reset halt
# resume
