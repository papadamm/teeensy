#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-longan-nano-gd32vf103cbt6.sh (also known as super simple sample code)
# this code for Longan Nano will control the LED on PC13
#
# Copyright (C) 2026 Magnus Damm
#
# this script builds some bundled tiny example code to generate a binary
# which may be used to test execution via a debugger on the target
# see further down in the file for some RISC-V assembly source code
#
# set CROSS_COMPILE to point out the toolchain
# riscv32-unknown-elf-gcc 6.1.0 and binutils 2.28.51.20170109 are known to work

# Sipeed Longan Nano (GD32VF103CBT6 with a Nuclei Bumblebee RISC-V core)
ARCH=rv32imac

# Probe for required software components
for e in cat grep mktemp rm wc which ${CROSS_COMPILE}gcc ${CROSS_COMPILE}as \
	     ${CROSS_COMPILE}ld ${CROSS_COMPILE}objcopy
do
    if [ -z `which $e` ]; then
        echo "unable to detect required software component $e, exiting" >&2
        exit 1;
    fi
done

# Check that CROSS_COMPILE actually points to a cross compiler for RISC-V
${CROSS_COMPILE}gcc -march=${ARCH} -xc /dev/null -S 2>/dev/null
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
  /* setup RCC_APB2ENR to enable clocks to GPIO blocks */
  /* clear PC13 using GPIOCBSRR to turn off the LED by default */
  /* configure GPIOC_CRH */
  /* clear/set PC13 using GPIOC_BSRR to enable/disable LED */
  /* (logic not far from teeensy-generic-stm32f103c8t6.sh) */

  li t0, 0x1fc
  li t1, 0x40021018 /* RCC_APB2ENR */
  sw t0, 0(t1)

  li t0, 0x00002000 /* LED is set to off by default */
  li t1, 0x40011010 /* GPIOC_BSRR */
  sw t0, 0(t1)

  li t0, 0x44344444
  li t1, 0x40011004 /* GPIOC_CRH */
  sw t0, 0(t1)
EOF

if [ "${1}" != "off" ]; then
cat <<EOF
  li t0, 0x20000000 /* turn on LED */
  li t1, 0x40011010 /* GPIOC_BSRR */
  sw t0, 0(t1)
EOF
fi

cat <<EOF
end:
  j end
EOF
}

output_asm $1 | ${CROSS_COMPILE}as -march=${ARCH} -o "${t0}"
${CROSS_COMPILE}ld --section-start=.text=0x08000000 "${t0}" -o "${t1}"
${CROSS_COMPILE}objcopy "${t1}" -O ihex "${t0}"
cat "${t0}" # the contents come out on stdout, used as "file.hex" below

# example using Segger J-Link Ultra 20-pin JTAG to Longan Nano J3 (and J2)
# Power and Ground: 1:VTref-3V3, 4:GND-GND,
# Debug port: 5:TDI-JTDI, 7:TMS-JTMS, 9:TCK-JTCK, 13:TDO-JTDO
# (Additional Reset: 3:nTRST-RST)
#
# openocd 0.12.0 is known to work
#
# openocd -f interface/jlink.cfg -c "transport select jtag" \
#         -f target/gd32vf103.cfg
#
# telnet localhost 4444
# reset_config trst_only
#
# (this erases the flash, LED is off by default)
# reset halt
# flash probe 0
# flash erase_sector 0 0 last
#
# (this programs the above software, allows control of the LED)
# reset halt
# program file.hex
# resume
