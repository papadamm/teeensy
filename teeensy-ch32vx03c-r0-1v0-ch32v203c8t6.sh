#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-ch32vx03c-r0-1v0-ch32v203c8t6.sh (super simple sample code)
# this code for ch32vx03c-r0-1v0 will pull down PC13 to turn on LED1
#
# Copyright (C) 2026 Magnus Damm
#
# this script builds some bundled tiny example code to generate a binary
# which may be used to test execution via a debugger on the target
# see further down in the file for some RISC-V assembly source code
#
# set CROSS_COMPILE to point out the toolchain
# riscv32-unknown-elf from binutils-2.47 is known to work

# ch32vx03c-r0-1v0 (ch32v203c8t6 with a QingKe V4B core (RISC-V RV32IMAC))
BINUTILS_OPTS="-march=rv32imac"

# Probe for required software components
for e in cat grep mktemp rm wc which ${CROSS_COMPILE}as \
	     ${CROSS_COMPILE}ld ${CROSS_COMPILE}objcopy
do
    if [ -z `which $e` ]; then
        echo "unable to detect required software component $e, exiting" >&2
        exit 1;
    fi
done

# Check that CROSS_COMPILE actually points to an assembler for RISC-V
AS_OPTS=${BINUTILS_OPTS}
${CROSS_COMPILE}as ${BINUTILS_OPTS} /dev/null -o /dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Failed to detect RISC-V support in CROSS_COMPILE, exiting" >&2
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
  /* turn on clock to GPIO PORTC via IOPCEN bit in RCC_APB2PCENR */
  /* setup R32_GPIOC_CFGHR to configure GPIO PC13 */

  li t0, 0x10 /* IOPCEN=1 */
  li t1, 0x40021018 /* RCC_APB2PCENR */
  sw t0, 0(t1)

  li t0, 0x44644444 /* MODE13[1:0], CNF13[1:0] setup, others reset default */
  li t1, 0x40011004 /* R32_GPIOC_CFGHR */
  sw t0, 0(t1)

  /* assume that the PC13 GPIO output reset state is zero */

end:
  j end
EOF
}

output_asm $1 | ${CROSS_COMPILE}as ${AS_OPTS} -o "${t0}"
${CROSS_COMPILE}ld --section-start=.text=0x08000000 "${t0}" -o "${t1}"
${CROSS_COMPILE}objcopy "${t1}" -O ihex "${t0}"
cat "${t0}" # the contents come out on stdout, used as "file.hex" below

# use a WCH-LinkE hardware debugger with open source wlink tool
# wlink version 0.1.2 is known to work on Mac OS X
#
# connect 3V3 and GND from hardware debugger to power the target board
# also connect SWDIO/TMS pin from hardware debugger to target board PA13
# also connect SWDCLK/TCK pin from hardware debugger to target board PA14
#
# the LEDs are on a pin header so connect PC13 to LED1 as well
#
# (to turn on the LED program the code using the wlink utility)
# % wlink flash file.hex
#
# (to turn off the LED erase the chip to remove the software)
# % wlink erase
