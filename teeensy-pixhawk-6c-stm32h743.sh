#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-pixhawk-6c-stm32h743.sh (super simple sample code)
# this code for "pixhawk 6c" turns on PD10/PD11 LEDs on the FMU (STM32H743)
#
# Copyright (C) 2026 Magnus Damm
#
# this script builds some bundled tiny example code to generate a binary
# which may be used to test execution via a debugger on the target
# see further down in the file for some ARM assembly source code
#
# set CROSS_COMPILE to point out the toolchain
# gcc-arm-none-eabi-6-2017-q2-update is known to work

# makes use of a stm32h743 (with a Cortex-M7)
ARCH=armv7e-m

# Probe for required software components
for e in cat grep mktemp rm wc which ${CROSS_COMPILE}as \
	     ${CROSS_COMPILE}ld ${CROSS_COMPILE}objcopy
do
    if [ -z `which $e` ]; then
        echo "unable to detect required software component $e, exiting" >&2
        exit 1;
    fi
done

# Check that CROSS_COMPILE actually points to an assembler for ARM
${CROSS_COMPILE}as -march=${ARCH} /dev/null -o /dev/null 2>/dev/null
if [ $? -ne 0 ]; then
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
  /* setup RCC_APB4ENR to enable clocks to GPIOD */
  /* configure GPIOD_MODER, clear/set PD10 and PD11 using GPIOD_BSRR */

  ldr r0, =0x00000008 /* GPIODEN = 1 */
  ldr r5, =0x580244e0 /* RCC_AHB4ENR */
  str r0, [r5]

  ldr r0, =0x00000c00 /* turn off LEDs by configuring PD10 + PD11 high */
  ldr r5, =0x58020c18 /* GPIOD_BSRR */
  str r0, [r5]

  ldr r0, =0x00500000 /* MODER10/11[1:0] = General purpose output mode */
  ldr r5, =0x58020c00 /* GPIOD_MODER */
  str r0, [r5]

  ldr r0, =0x0c000000 /* turn on the LEDs by configuring PD10 + PD11 low */
  ldr r5, =0x58020c18 /* GPIOD_BSRR */
  str r0, [r5]

end:
  b end

  .align 2
  .pool
EOF

${CROSS_COMPILE}ld --section-start=.text=0x08000000 "${t0}" -o "${t1}"
${CROSS_COMPILE}objcopy "${t1}" -O ihex "${t0}"
cat "${t0}" # the contents come out on stdout, used as "file.hex" below

# example of a Segger J-Link Ultra+ via a debug board and "FMU Debug" port
# openocd 0.12.0 is known to work
#
# openocd -f interface/jlink.cfg -c "transport select swd" \
#         -f target/stm32h7x.cfg
# telnet localhost 4444

# (erase the flash on the board which causes the LEDs to be off at power on)
# halt
# flash erase_sector 0 0 last
# reset halt
# resume

# (program the above software which will make the LEDs light up at power on)
# halt
# program file.hex
# reset halt
# resume
