#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-sparkfun-pro-micro-rp2040.sh (super simple sample code)
# this code for "Sparkfun Pro Micro" turns on the WS2812B-2020 LED
#
# Copyright (C) 2026 Magnus Damm
#
# this script builds some bundled tiny example code to generate
# a binary which may be used to test execution on the target
# see further down in the file for some ARM assembly source code
#
# set CROSS_COMPILE to point out the toolchain
# gcc-arm-none-eabi-6-2017-q2-update is known to work

# makes use of a rp2040 (with a Cortex-M0+)
ARCH=armv6s-m

# Probe for required software components
for e in cat grep mktemp rm uuencode wc which ${CROSS_COMPILE}gcc \
	     ${CROSS_COMPILE}as ${CROSS_COMPILE}ld ${CROSS_COMPILE}objcopy
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
  .align 1
  .global _start
  .type _start, %function
_start:
  /* initialize GPIO25 as output for WS2812B-2020 control */

  ldr r0, =0x00000120 /* PADS_BANK0 + IO_BANK0 */
  ldr r5, =(0x4000c000 + 0x3000) /* RESET_RESETS (CLR alias) */
  str r0, [r5]

  movs r0, #5
  ldr r5, =(0x400140cc + 0x0000) /* GPIO25_CTRL (normal alias) */
  str r0, [r5]

  ldr r0, =(1 << 25) /* GPIO25 */
  ldr r5, =(0xd0000024 + 0x0000) /* GPIO_OE_SET (normal alias) */
  str r0, [r5]

  /* generate a waveform for WS2812B-2020 */
  /* 1 x 300us reset */
  /* 24 x ( T1H (740ns) + T1L (370ns) ) */

  ldr r5, =(0xd0000014 + 0x0000) /* GPIO_OUT_SET (normal alias) */
  ldr r6, =(0xd0000018 + 0x0000) /* GPIO_OUT_CLR (normal alias) */

  movs r3, #1  /* first run one dummy change */
  movs r4, #2  /* reset + second run when cached */

  str r0, [r5] /* low to high (initial setup, end of T0H, start of T1H) */
loop:
  str r0, [r6] /* clear or toggle */
  nop
loop2:
  str r0, [r6] /* clear or toggle */
  subs r3, #1
  bne loop

  ldr r2, =410  /* duration of a 300 us reset pulse */ 
dly:
  subs r2, #1
  bne dly

  ldr r6, =(0xd000001c + 0x0000) /* GPIO_OUT_XOR (normal alias) */
  movs r3, #25 /* generate 24 identical pulses */
  subs r4, #1
  bne loop2

end:
  b end

  .align 2
  .pool
EOF

${CROSS_COMPILE}ld --section-start=.text=0x10000100 "${t0}" -o "${t1}"
${CROSS_COMPILE}objcopy "${t1}" -O binary "${t0}"
cat "${t0}" | uuencode - # contents on stdout, used as "file.uue" below

# use picotool to program the device over USB
# picotool v2.2.0 is known to work
#
# (this teensy code depends on a boot loader binary "boot2.bin")
# ("picotool info" revealed that the blink example was preinstalled)
# (https://github.com/raspberrypi/pico-examples/tree/HEAD/blink)
# (it may be extracted with "picotool save" in bin format)
# (convert the first 256 byte to a separate file using dd)
# (disassemble with objdump -D boot2.bin -b binary -m arm -M force-thumb)
#
# (to clear the device of any user software use "picotool erase")
# (in the erased state the LED is off by default)
#
# (the teeensy code to turn on the LED is flashed like this)
# 0x10000000: 256-byte Second Stage Bootloader binary "boot2.bin"
# 0x10000100: teeensy stdout contents converted into a binary
# load the single binary file onto the device using picotool 
# 
# cat boot2.bin > file.bin
# cat file.uue | uudecode -o /dev/stdout >> file.bin
# picotool load -t bin file.bin
#
# (the device needs to be put into BOOTSEL mode before invoking picotool)
#
# (random comments: the LED is very bright and must be rather power hungry)
# (if using USB-A to USB-C converter the LED might just blink at power on)
# (in such a case press S1 RESET to force a reset which turns on the LED)
# (a regular USB-C to USB-C cable makes the LED turn on immediately)
