#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-rza2m-evk-r7s9210.sh (super simple sample code)
# this code for RZ/A2M Evaluation Kit turns on LED1 via PC_1
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
BINUTILS_OPTS="-march=armv7-a"
CLANG_OPTS="--target=arm -mcpu=cortex-a9"

# Probe for required software components
for e in cat mktemp rm which ${CROSS_COMPILE}as ${CROSS_COMPILE}objcopy
do
    if [ -z `which $e` ]; then
        echo "unable to detect required software component $e, exiting" >&2
        exit 1;
    fi
done

# Check that CROSS_COMPILE actually points to an assembler for ARM
AS_OPTS=${CLANG_OPTS}
${CROSS_COMPILE}as ${CLANG_OPTS} /dev/null -o /dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    AS_OPTS=${BINUTILS_OPTS}
    ${CROSS_COMPILE}as ${BINUTILS_OPTS} /dev/null -o /dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Failed to detect ARM support in CROSS_COMPILE, exiting" >&2
        exit 1;
    fi
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

  .global _start
  .type _start, %function
_start:
  /* initialize PC_1 as output set high */

  movs r0, #0x0c /* PDR1[1:0] */
  ldr r5, =0xfcffe018 /* PORTC.PDR (16-bit) */
  strh r0, [r5]

  movs r0, #0x02 /* PODR1 */
  ldr r5, =0xfcffe04c /* PORTC.PODR (8-bit) */
  strb r0, [r5]

end:
  b end

  .align 2
  .pool
EOF
}

emit_asm | ${CROSS_COMPILE}as ${AS_OPTS} -mlittle-endian -o "${t0}"
${CROSS_COMPILE}objcopy --change-section-address=.text=0x80200000 \
                "${t0}" -O ihex "${t1}"
# output hex file to stdout (used as file.hex below)
cat "${t1}"

# example using Segger J-Link LITE connected to mini 20-pin JTAG port CN5
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
