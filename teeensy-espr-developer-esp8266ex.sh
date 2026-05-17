#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-espr-developer-esp8266ex.sh (also known as super simple sample code)
# this code for Switch Science ESPr Developer will blink the TX LED
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
# xtensa-lx106-elf-gcc (GCC) 10.3.0
# GNU assembler (GNU Binutils) 2.32

# The ESP8266 contains a Tensilica Xtensa 32-bit LX6
ARCH=lx106

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
    echo "Failed to detect ESP8266 support in CROSS_COMPILE, exiting" >&2
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

  /* there is no LED hooked up to any GPIO of the ESP-WROOM-02 directly */
  /* as a workaround, pull GPIO1 low to transmit BREAK chars on TXD */

  /* load value 0x60000000 into a2 (shared GPIO/MUX base address) */
  movi.n  a2, 6
  slli    a2, a2, 28

  /* 0x60000818: PERIPHS_IO_MUX_U0TXD_U */
  movi.n  a3, 0x30 /* FUNC_GPIO1 */
  movi    a4, 0x08
  slli    a4, a4, 8
  add     a5, a2, a4
  s32i    a3, a5, 0x18

  /* 0x60000310: GPIO_ENABLE_W1TS_REG (GPIO set to output) */
  movi.n  a3, 0x02
  movi    a4, 0x03
  slli    a4, a4, 8
  add     a5, a2, a4
  s32i    a3, a5, 0x10

loop:
  /* 0x60000304: GPIO_OUT_W1TS_REG (set output data to 1) */
  movi.n  a3, 0x02
  movi    a4, 0x03
  slli    a4, a4, 8
  add     a5, a2, a4
  s32i    a3, a5, 0x04

  /* keep GPIO1 high about 1.5 ms */
  movi.n  a1, 0x01
  slli    a1, a1, 14
  movi.n  a3, 0x00
dly_h:
  nop
  addi    a1, a1, -1
  bne     a3, a1, dly_h

  /* 0x60000308: GPIO_OUT_W1TC_REG (clear output data to 0) */
  movi.n  a3, 0x02
  movi    a4, 0x03
  slli    a4, a4, 8
  add     a5, a2, a4
  s32i    a3, a5, 0x08

  /* keep GPIO1 low about 120 us, this is one BREAK char @ 76800 bps */
  movi.n  a1, 0x01
  slli    a1, a1, 10
  movi.n  a3, 0x00
dly_l:
  nop
  addi    a1, a1, -1
  bne     a3, a1, dly_l

  .end no-transform
  j    loop
EOF
}

output_asm | ${CROSS_COMPILE}as -o "${t0}"
${CROSS_COMPILE}ld --section-start=.text=0x40100000 "${t0}" -o "${t1}"
cat "${t1}" | uuencode - # the contents come out on stdout

# the code is uploaded via esptool to the board through the micro-USB port
#
# esptool v5.2.0 is known to work
#
# (to erase the device, use the erase-flash command)
# esptool -p /dev/cu.usbserial-DN03V99L erase-flash
#
# (the output from stdout needs to be converted using elf2image)
# cat file.uue | uudecode -o file.o
# esptool -c esp8266 elf2image file.o -o file.img
#
# (to turn on the LED, program the above software into flash like this)
# esptool -p /dev/cu.usbserial-DN03V99L --chip=esp8266 \
#  --no-stub write-flash 0 file.img0x00000.bin
#
# (after programming a waveform with BREAK signals will appear on the TXD pin)
# (also the TX LED will appear to be lit, however only for a while)
# (the FT231XS chip seems to get confused and the TX LED gets turned off)
# (this is related to the state of the DTR signal, workaround by using stty)
# stty -f /dev/cu.usbserial-DN03V99L cread
#
# (the above stty command will make the TX LED turn on for about 0.5s again)
# (this may be repeated as long as the code above is running on the ESP8266)
# (with the device erased "stty cread" will make the TX LED flash once)
