#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-generic-esp32-cam-esp32-s.sh (also known as super simple sample code)
# this code for ESP32_CAM will turn on the GPIO33 LED
#
# Copyright (C) 2026 Magnus Damm
#
# this script builds some bundled tiny example code to generate a binary
# which may be used to test execution via a debugger on the target
# see further down in the file for some tensilica assembly source code
#
# set CROSS_COMPILE to point out the toolchain
#
# known working toolchain:
# xtensa-esp32s3-elf-gcc (crosstool-NG esp-2021r2-patch5) 8.4.0
# GNU assembler (crosstool-NG esp-2021r2-patch5) 2.35.1.20201223

# The ESP32-S contains a Tensilica Xtensa 32-bit LX6
ARCH=esp32s

# Probe for required software components
for e in cat grep mktemp rm uuencode wc which ${CROSS_COMPILE}gcc \
	     ${CROSS_COMPILE}as ${CROSS_COMPILE}ld
do
    if [ -z `which $e` ]; then
        echo "unable to detect required software component $e, exiting" >&2
        exit 1;
    fi
done

# Check that CROSS_COMPILE actually points to a cross compiler for ESP32-S
if [ `${CROSS_COMPILE}gcc -dumpmachine | grep ${ARCH} | wc -l` -ne 1 ]; then
    echo "Failed to detect ESP32-S support in CROSS_COMPILE, exiting" >&2
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

output_asm ()
{
cat <<EOF
  .text
  .global _start
  .type _start, %function
_start:
  .begin no-transform

  /* load value 0x3ff40000 into a2 (shared GPIO/MUX base address) */
  movi.n  a2, 0x40
  slli    a2, a2, 24
  movi    a4, 0x0c
  slli    a4, a4, 16
  sub     a2, a2, a4

  /* 0x3ff49020: IO_MUX_GPIO33_REG */
  movi.n  a3, 0x00 /* All zero including MCU_SEL=0 */
  movi    a4, 0x09
  slli    a4, a4, 12
  add     a5, a2, a4
  s32i    a3, a5, 0x20

  /* 0x3ff44030: GPIO_ENABLE1_W1TS_REG */
  movi.n  a3, 0x02 /* bit 1 GPIO 33 */
  movi    a4, 0x04
  slli    a4, a4, 12
  add     a5, a2, a4
  s32i    a3, a5, 0x30

  /* we rely on that the reset default for GPIO 33 is low */

  .end no-transform
1:
  j    1b
EOF
}

output_asm | ${CROSS_COMPILE}as -o "${t0}"
${CROSS_COMPILE}ld --section-start=.text=0x40080000 "${t0}" -o "${t1}"
cat "${t1}" | uuencode - # the contents come out on stdout

# the code is uploaded via esptool to the board through the micro-USB port
#
# esptool v5.2.0 is known to work
#
# (to erase the device, use the erase-flash command. the LED will be off)
# esptool -p /dev/cu.usbserial-14140 erase-flash
#
# (the output from stdout needs to be converted using elf2image)
# cat file.uue | uudecode -o file.o
# esptool -c esp32 elf2image file.o -o file.img
#
# (to turn on the LED, load the above software into memory like this)
# esptool -p /dev/cu.usbserial-14140 --chip=esp32 --no-stub load-ram file.img
