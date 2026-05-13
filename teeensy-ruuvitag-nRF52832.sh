#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-ruuvitag-nRF52832.sh (also known as super simple sample code)
# this code for RuuviTag will turn on LED2 connected to P0.19
#
# Copyright (C) 2026 Magnus Damm
#
# this script builds some bundled tiny example code to generate a binary
# which may be used to test execution via a debugger on the target
# see further down in the file for some ARM assembly source code
#
# set CROSS_COMPILE to point out the toolchain
# gcc-arm-none-eabi-6-2017-q2-update is known to work

# RuuviTag (nRF52832 with a Cortex-M4)
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
  /* setup P0.19 as output but before that set the GPIO value to high */
  /* then pull the GPIO low to enable the LED */
	
  movs r0, #0x80000 /* 1 << 19 (P0.19) */
  ldr r5, =0x50000508 /* nRF52832 GPIO OUTSET */
  str r0, [r5] /* this makes sure the LED remains off */

  movs r0, #0x03
  ldr r5, =0x5000074c /* nRF52832 GPIO PIN_CNF[19] (P0.019) */
  str r0, [r5] /* select output pin function, LED still off */

  movs r0, #0x80000 /* 1 << 19 (P0.19) */
  ldr r5, =0x5000050c /* nRF52832 GPIO OUTCLR */
  str r0, [r5] /* clearing the GPIO will make the LED turn on */

end:
  b end

  .align 2
  .pool
EOF

${CROSS_COMPILE}ld --section-start=.text=0 "${t0}" -o "${t1}"
${CROSS_COMPILE}objcopy "${t1}" -O ihex "${t0}"
cat "${t0}" # the contents come out on stdout, used as "file.hex" below

# example using Segger J-Link LITE connected to RuuviTag Development Shield
#
# 20-pin JTAG 4-wire SWD connection:
# Power and Ground: 1:VTref - VCC, 4:GND - GND
# SWD signals: 7:TMS - SWDIO, 9:TCK - SWDCLK
#
# openocd 0.12.0 is known to work
#
# openocd -f interface/jlink.cfg -c "transport select swd" \
#	-f target/nrf52.cfg -c "init"
# telnet localhost 4444
# reset halt; program file.hex; resume
