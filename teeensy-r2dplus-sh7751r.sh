#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-r2dplus-sh7751r.sh (super simple sample code)
# this code for R0P751RLC0011RL turns on LED9-16 connected to the FPGA @ CS1
#
# Copyright (C) 2026 Magnus Damm
#
# this script builds some bundled tiny example code to generate
# a binary which may be used to test execution on the target
# see further down in the file for some SuperH assembly source code
#
# set CROSS_COMPILE to point out the toolchain
# sh4-unknown-elf from binutils-2.47 is known to work

# makes use of a Renesas SH7751R (with a SH4 core)
BINUTILS_OPTS="--isa=sh4 --little"

# Probe for required software components
for e in cat mktemp rm uuencode which \
         ${CROSS_COMPILE}as ${CROSS_COMPILE}objcopy
do
    if [ -z `which $e` ]; then
        echo "unable to detect required software component $e, exiting" >&2
        exit 1;
    fi
done

# Check that CROSS_COMPILE actually points to an assembler for SuperH
AS_OPTS=${BINUTILS_OPTS}
${CROSS_COMPILE}as ${BINUTILS_OPTS} /dev/null -o /dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Failed to detect SuperH support in CROSS_COMPILE, exiting" >&2
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
  .global _start
  .type _start, %function
_start:
  /* Simple code to output a pattern on the Debug LEDs of the R2D+ */
  /* Access LEDs via the OUTPORT register of the FPGA connected to CS1 */

  mov #0xbd, r1
  mov.l 2f, r0
  mov.w	r1, @r0

1:
  bra 1b

  .align 2
2:
  .long 0x04000036 | 0xe0000000 /* P4 of 16-bit OUTPORT register */
EOF
}

emit_asm | ${CROSS_COMPILE}as ${AS_OPTS} -o "${t0}"
${CROSS_COMPILE}objcopy "${t0}" -O binary "${t1}"
# output hex file to stdout (used as file.uue below)
cat "${t1}" | uuencode -

# JTAG pins are exposed on CN1 however this example makes use of CN9 and a CF
# loaded automatically by 'b' command of the boot loader stored in NOR flash
# the 115200n81 serial console outputs "SH IPL+eth version 1.0" as well as
# "Board Rev. 2.1 < FPGA = 1.01 >  Kernel Loader Rev. 3.01(m)"
# original code on CF card is some sort of MBR LILO and a Linux kernel
#
# (use the dd utility to write to CF, Mac OS X example below)
# cat file.uue | uudecode -o /dev/stdout > file.bin
# diskutil list
# sudo dd if=file.bin bs=512 count=1 of=/dev/diskX
# diskutil eject
