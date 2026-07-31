#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-adafruit-feather-nrf52840.sh (super simple sample code)
# this code for Bluefruit Sense will turn on/off BLUE_LED (P1.10)
#
# Copyright (C) 2026 Magnus Damm
#
# this script builds some bundled tiny example code to generate
# a binary which may be used to test execution on the target
# see further down in the file for some ARM assembly source code
#
# set CROSS_COMPILE to point out the toolchain
# gcc-arm-none-eabi-6-2017-q2-update is known to work

# Adafruit Feather BlueFruit Sense (nRF52840 with a Cortex-M4)
BINUTILS_OPTS="-march=armv7e-m"

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
${CROSS_COMPILE}as ${BINUTILS_OPTS} /dev/null -o /dev/null 2>/dev/null
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

emit_asm ()
{
cat <<EOF
  .syntax unified

  .global vector_table
vector_table:
  .long 0 /* Top of stack set to nothing since unused */
  .long _start
  .space 126 * 4

  .align 1
  .global _start
  .type _start, %function
_start:
  /* setup P1.10 as output with GPIO value set to high to turn on the LED */

  movs r0, #0x400 /* 1 << 10 (P1.10) */
  ldr r5, =0x5000080c /* nRF52840 GPIO OUTCLR */
  str r0, [r5]

  movs r0, #0x03
  ldr r5, =0x50000a28 /* nRF52840 GPIO PIN_CNF[10] (P1.10) */
  str r0, [r5]
EOF
if [ "$1" != "off" ]; then
cat <<EOF
  movs r0, #0x400 /* 1 << 10 (P1.10) */
  ldr r5, =0x50000808 /* nRF52840 GPIO OUTSET */
  str r0, [r5]
EOF
fi

cat <<EOF
end:
  b end

  .align 2
  .pool
EOF
}

emit_asm $1 | ${CROSS_COMPILE}as ${BINUTILS_OPTS} -mlittle-endian -o "${t0}"
${CROSS_COMPILE}ld --section-start=.text=0x26000 "${t0}" -o "${t1}"
${CROSS_COMPILE}objcopy "${t1}" -O ihex "${t0}"
cat "${t0}" # the contents come out on stdout, used as "file.hex" below

# uf2conf.py from commit f3f9f1e @ https://github.com/microsoft/uf2.git
# boot loader is "UF2 Bootloader 0.8.0" with "SoftDevice: S140 6.1.1"
#
# (convert hex file to UF2 format with uf2conf.py)
# % python3.11 ~/uf2conv.py file.hex -c -f 0xADA52840 -o file.uf2
# % file file.uf2
# file.uf2: UF2 firmware image, family Nordic NRF52840, address 0x026000, 3 total blocks
# (copy file onto device that is hooked up as USB disk)
# % cp -X file.uf2 /Volumes/FTHRSNSBOOT 2> /dev/null
# (USB disk gets automatically ejected and the LED gets lid)
#
# pass off to this script and the generated code will keep the LED off
