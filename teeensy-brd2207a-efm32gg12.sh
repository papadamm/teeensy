#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-brd2207a-efm32gg12.sh (also known as super simple sample code)
# this code for Thunderboard EF32GG12 will turn on LED0 connected to PA
#
# Copyright (C) 2026 Magnus Damm
#
# this script builds some bundled tiny example code to generate a binary
# which may be used to test execution via a debugger on the target
# see further down in the file for some ARM assembly source code
#
# set CROSS_COMPILE to point out the toolchain
# gcc-arm-none-eabi-6-2017-q2-update is known to work

# BRD2207A (Silicon Labs EFM32GG12 with a Cortex-M4)
ARCH=armv7e-m

# Probe for required software components
for e in cat grep mktemp rm wc which ${CROSS_COMPILE}gcc ${CROSS_COMPILE}as \
	     ${CROSS_COMPILE}ld ${CROSS_COMPILE}objcopy
do
    if [ -z `which $e` ]; then
        echo "unable to detect required software component $e, exiting" >&2
        exit 1;
    fi
done

# Check that CROSS_COMPILE actually points to a cross compiler for ARM
${CROSS_COMPILE}gcc -march=${ARCH} -xc /dev/null -S 2>/dev/null
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
  /* setup PA12, PA13, PA14 as output but before that enable the GPIO in CMU */
	
  movs r0, #0x10 /* 1 << 4 (GPIO) */
  ldr r5, =0x400e40b0 /* CMU_HFBUSCLKEN0 */
  str r0, [r5] /* turn on clocks to the on-chip GPIO device */

  ldr r0, =0x08880000 /* PA14, PA13, PA12 WIREDAND */
  ldr r5, =0x40088008 /* GPIO_PA_MODEH */
  str r0, [r5] /* the RGB LED becomes white at this point */

end:
  b end

  .align 2
  .pool
EOF

${CROSS_COMPILE}ld --section-start=.text=0 "${t0}" -o "${t1}"
${CROSS_COMPILE}objcopy "${t1}" -O ihex "${t0}"
cat "${t0}" # the contents come out on stdout, used as "file.hex" below

# example using the on-board Segger J-Link debugger
# openocd 0.12.0 is known to work
#
# openocd -f interface/jlink.cfg -c "transport select swd" -f target/efm32.cfg
#
# (this will erase the flash on the device, resulting in no LED output)
# reset halt
# flash erase_sector 0 0 last  
# resume
#
# (this will program the above software, resulting in the LED turning on)
# reset halt; program file.hex; resume
