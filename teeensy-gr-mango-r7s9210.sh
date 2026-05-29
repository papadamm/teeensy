#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-gr-mango-r7s9210.sh (super simple sample code)
# this code for "GR-MANGO" turns on LED2 connected to P0_3
#
# Copyright (C) 2026 Magnus Damm
#
# this script builds some bundled tiny example code to generate
# a binary which may be used to test execution on the target
# see further down in the file for some ARM assembly source code
#
# set CROSS_COMPILE to point out the toolchain
# gcc-arm-none-eabi-6-2017-q2-update is known to work

# makes use of a Renesas RZ/A2M aka r7s9210 (with a single core Cortex-A9)
ARCH=armv7-a

# Probe for required software components
for e in cat mktemp rm which \
	    ${CROSS_COMPILE}as ${CROSS_COMPILE}ld ${CROSS_COMPILE}objcopy
do
    if [ -z `which $e` ]; then
        echo "unable to detect required software component $e, exiting" >&2
        exit 1;
    fi
done

# Check that CROSS_COMPILE actually points to an assembler for ARM
${CROSS_COMPILE}as -march=${ARCH} /dev/null -o /dev/null 2>/dev/null
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

emit_asm () {
  cat <<EOF
  .syntax unified
  .arch ${ARCH}

  .arm
  .text
  .align 1
  .global _start
  .type _start, %function
_start:
  /* initialize P0_3 as output set high */

  movs r0, #0xc0 /* PDR3[1:0] */
  ldr r5, =0xfcffe000 /* PORT0.PDR (16-bit) */
  strh r0, [r5]

  movs r0, #0x08 /* PODR3 */
  ldr r5, =0xfcffe040 /* PORT0.PODR (8-bit) */
  strb r0, [r5]

end:
  b end

  .align 2
  .pool
EOF
}

emit_asm | ${CROSS_COMPILE}as -mlittle-endian -o "${t0}"
${CROSS_COMPILE}ld --section-start=.text=0x80200000 "${t0}" -o "${t1}"
${CROSS_COMPILE}objcopy "${t1}" -O ihex "${t0}"
# output hex file to stdout (used as file.hex below)
cat "${t0}"

# example using Segger J-Link LITE connected to 10-pin JTAG port
# openocd 0.12.0 is known to work (with r7s72100 in place of r7s9210)
#
# openocd -f interface/jlink.cfg -c "transport select jtag" \
#       -f target/renesas_r7s72100.cfg -c "adapter speed 50000"
# telnet localhost 4444

# (load software to on-chip RAM)
# reset_config srst_only
# reset halt
# load_image file.hex
# arm core_state arm
# resume 0x80200000
