#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-arduino-nano-every-atmega4809.sh (super simple sample code)
# this code for Arduino Nano Every will control the "DL1" LED on PE02
#
# Copyright (C) 2026 Magnus Damm
#
# this script builds some bundled tiny example code to generate a binary
# which may be used to test execution via a debugger on the target
# see further down in the file for some AVR assembly source code
#
# set CROSS_COMPILE to point out the toolchain
# binutils 2.26.20160125 (bundled with avr-gcc 7.3.0) is known to work

# Arduino Nano Every uses a ATMEGA4809 MCU
MCU=atmega48

# Probe for required software components
for e in cat grep mktemp rm wc which ${CROSS_COMPILE}as ${CROSS_COMPILE}objcopy
do
    if [ -z `which $e` ]; then
        echo "unable to detect required software component $e, exiting" >&2
        exit 1;
    fi
done

# Check that CROSS_COMPILE actually points to an assembler for AVR
${CROSS_COMPILE}as -mmcu=${MCU} /dev/null -o /dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Failed to detect AVR support in CROSS_COMPILE, exiting" >&2
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

output_asm ()
{
cat <<EOF
  .text
  /* set bit 2 in PORTE.DIRSET to configure PE02 as output */
  ldi r18, 1 << 2 /* bit 2 from PE02 */
  sts 0x0481 ,r18 /* PORTE.DIRSET */
EOF
if [ "${1}" == "off" ]; then
cat <<EOF
  /* set bit 2 in PORTE.OUTCLR to set PE02 low (and turn off LED) */
  ldi r18, 1 << 2 /* bit 2 from PE02 */
  sts 0x0486 ,r18 /* PORTE.OUTCLR */
EOF
else
cat <<EOF
  /* set bit 2 in PORTE.OUTSET to set PE02 high (and turn on LED) */
  ldi r18, 1 << 2 /* bit 2 from PE02 */
  sts 0x0485 ,r18 /* PORTE.OUTSET */
EOF
fi
cat <<EOF
end:
  rjmp end
EOF
}

# turn on break-on-failure
set -e

output_asm $1 | ${CROSS_COMPILE}as -mmcu=${MCU} -o "${t0}"
${CROSS_COMPILE}objcopy "${t0}" -O ihex "${t1}"
cat "${t1}" # the contents come out on stdout, used as "file.hex" below

# use avrdude to program the device over USB
# avrdude version 8.3 is known to work
#
# (by default the LED is turned on by this software)
# (to disable the LED, pass "off" to this script)
# avrdude -v -p atmega4809 -c jtag2updi -P /dev/tty.usbmodem14301 \
#  -e -D -U flash:w:file.hex:i
#
# (before executing avrdude above the serial port needs to be set to 1200 bps)
# stty -f /dev/tty.usbmodem14301 1200
