#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-phyx-lana-tny01-ch32v203g6u6.sh (super simple sample code)
# this code for Phyx LANA TNY.01 will turn on the RGB LED at PD0
# more information is available at https://www.adafru.it/6042
#
# Copyright (C) 2026 Magnus Damm
#
# this script builds some bundled tiny example code to generate a binary
# which may be used to test execution via a debugger on the target
# see further down in the file for some RISC-V assembly source code
#
# set CROSS_COMPILE to point out the toolchain
# riscv32-unknown-elf from binutils-2.47 is known to work

# ch32v203g6u6 (with a QingKe V4B core (RISC-V RV32IMAC))
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

  li t0, 0x21 /* IOPDEN=1, AFIOEN=1 */
  li t1, 0x40021018 /* RCC_APB2PCENR */
  sw t0, 0(t1)

  li t0, 0x00008000 /* PD0PD1_RM=1 */
  li t1, 0x40010004 /* R32_AFIO_PCFR1 */
  sw t0, 0(t1)

  li t0, 0x44444443 /* MODE0[1:0], CNF0[1:0] setup, others reset default */
  li t1, 0x40011400 /* R32_GPIOD_CFGLR */
  sw t0, 0(t1)

  /* a2: the GPIO value used to set the pin */
  /* a3: the GPIO value used to clear the pin */
  /* a4: the GPIO clear/set register */

  li a2, 1 << 0 /* set GPIO output to 1 */
  li a3, 1 << 16 /* clear GPIO output to 0 */
  li a4, 0x40011410 /* R32_GPIOD_BSHR */

  /* set the pin to 1 here to start in high state */

  sw a2, 0(a4) /* set GPIO output to 1 */

  /* generate a waveform for WS2812B-2020 */
  /* 1 x 300us reset */
  /* 24 x ( T1H (740ns) + T1L (370ns) ) */

  sw a3, 0(a4) /* clear GPIO output to 0 */

  li t0, 602 /* duration of a 300 us reset pulse */ 
dly:
  nop
  addi t0, t0, -1
  bnez t0, dly

  li t0, 25
loop:
  sw a3, 0(a4) /* clear GPIO output to 0 */
  sw a2, 0(a4) /* set GPIO output to 1 */
  addi t0, t0, -1
  bnez t0, loop

  sw a3, 0(a4) /* clear GPIO output to 0 */

end:
  j end
EOF
}

output_asm $1 | ${CROSS_COMPILE}as ${AS_OPTS} -o "${t0}"
${CROSS_COMPILE}ld --section-start=.text=0x08000000 "${t0}" -o "${t1}"
${CROSS_COMPILE}objcopy "${t1}" -O ihex "${t0}"
cat "${t0}" # the contents come out on stdout, used as "file.hex" below

# use the USB-C connector for power, ground and programming
# wchisp 0.3.0 is known to work on Mac OS X
#
# the device needs to be rebooted into the boot loader before programming
# to do so keep the PB8 BOOT button pressed while applying power via USB-C
#
# (use the probe command to see if the device has entered the boot loader)
# % wchisp probe
#
# (to turn on the LED program the above software using the flash command)
# % wchisp flash file.hex
#
# (to turn off the LED erase the chip to remove the software)
# % wchisp erase
