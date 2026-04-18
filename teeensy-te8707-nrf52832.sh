#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-te8707-nrf52832.sh (also known as super simple sample code)
# this code for TE8707 will make the RX LED twinkle once after reset
#
# Copyright (C) 2026 Magnus Damm
#
# this script builds some bundled tiny example code to generate a binary
# which may be used to test execution via a debugger on the target
# see further down in the file for some ARM assembly source code
#
# set CROSS_COMPILE to point out the toolchain
# gcc-arm-none-eabi-6-2017-q2-update is known to work

# Taiyo Yuden TE8707 contains EYSHSN (nRF52832 with a Cortex-M4)
ARCH=armv7e-m

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
  /* setup P0.06 as output and pull down briefly to emulate a UART BREAK */
  /* on the FT232 RXD input which will make D3 RX_LED emit a quick blink */
	
  ldr r5, =0x50000718 /* nRF52832 GPIO PIN_CNF[6] (P0.06) */
  movs r0, #0x03
  str r0, [r5]

  movs r0, #0x40 /* 1 << 6 (P0.06) */

  ldr r5, =0x50000508 /* nRF52832 GPIO OUTSET */
  str r0, [r5]
	
  ldr r5, =0x5000050c /* nRF52832 GPIO OUTCLR */
  str r0, [r5]

end:
  b end

  .align 2
  .pool
EOF

${CROSS_COMPILE}ld --section-start=.text=0 "${t0}" -o "${t1}"
${CROSS_COMPILE}objcopy "${t1}" -O ihex "${t0}"
cat "${t0}" # the contents come out on stdout, used as "file.hex" below

# example using Segger J-Link Ultra connected to TE8707 CN1
# openocd 0.12.0 is known to work
#
# openocd -f interface/jlink.cfg -c "transport select swd" \
#	-f target/nrf52.cfg -c "init"
# telnet localhost 4444
# reset halt; program file.hex; resume
