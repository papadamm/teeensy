#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-arduino-due-at91sam3x8e.sh (also known as super simple sample code)
# this code for Arduino Due will turn on the "L" LED
#
# Copyright (C) 2026 Magnus Damm
#
# this script builds some bundled tiny example code to generate a binary
# which may be used to test execution via a debugger on the target
# see further down in the file for some ARM assembly source code
#
# set CROSS_COMPILE to point out the toolchain
# gcc-arm-none-eabi-6-2017-q2-update is known to work

# Arduino Due uses a AT91SAM3X8E (with a Cortex-M3)
ARCH=armv7-m

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
  /* PB27 LED: PIOB at 0x400e1000, bit 27 0x08000000 */
  /* init sequence to output 1: OWER, PER, SODR, OER */
  /* to turn LED on: SODR */
  /* to turn LED off: CODR */

  ldr r0, =0x08000000
	
  ldr r5, =0x400e10a0 /* PIOB OWER */
  str r0, [r5]

  ldr r5, =0x400e1000 /* PIOB PER */
  str r0, [r5]

  ldr r5, =0x400e1030 /* PIOB SODR */
  str r0, [r5]

  ldr r5, =0x400e1010 /* PIOB OER */
  str r0, [r5]

  /* ldr r5, =0x400e1034 */ /* PIOB CODR */
  /* str r0, [r5] */

end:
  b end

  .align 2
  .pool
EOF

${CROSS_COMPILE}ld --section-start=.text=0x00080000 "${t0}" -o "${t1}"
${CROSS_COMPILE}objcopy "${t1}" -O ihex "${t0}"
cat "${t0}" # the contents come out on stdout, used as "file.hex" below

# example using Segger J-Link Ultra connected to JTAG port
# openocd 0.12.0 is known to work
#
# openocd -f interface/jlink.cfg -c "transport select swd" \
#	-c "set CHIPNAME atsam3X8E" -c "set CPUTAPID 0x2ba01477" \
# -f target/at91sam3ax_8x.cfg
# telnet localhost 4444

# (sequence below to erase all flash and set GPNVM1 to enable flash boot)
# reset halt
# flash erase_sector 0 0 last
# flash erase_sector 1 0 last
# at91sam3 gpnvm set 1
# (this instructs the device to boot from an empty flash which will fail)
# (after erase the "L" LED will now be off in case the board is power cycled)
#
# (sequence below to program the above code to the flash and enable flash boot)
# reset halt
# program file.hex
# at91sam3 gpnvm set 1
# resume
# (this will result in the "L" LED being lit at power on) */
# (the device will self-reset after a while, probably due to the watchdog) */
