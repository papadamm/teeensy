#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-seeeduino-nano-atmega328p.sh (also known as super simple sample code)
# this code for Seeeduino Nano will control the "L" LED on PB5
#
# Copyright (C) 2026 Magnus Damm
#
# this script builds some bundled tiny example code to generate a binary
# which may be used to test execution via a debugger on the target
# see further down in the file for some AVR assembly source code
#
# set CROSS_COMPILE to point out the toolchain
# avr-gcc 7.3.0 and binutils 2.26.20160125 are known to work

# Seeeduio Nano uses a ATMEGA328P MCU
MCU=atmega328p

# Probe for required software components
for e in cat grep mktemp rm wc which ${CROSS_COMPILE}gcc ${CROSS_COMPILE}as \
	     ${CROSS_COMPILE}objcopy
do
    if [ -z `which $e` ]; then
        echo "unable to detect required software component $e, exiting" >&2
        exit 1;
    fi
done

# Check that CROSS_COMPILE actually points to a cross compiler for AVR
if [[ `${CROSS_COMPILE}gcc --target-help | grep ${MCU} | wc -l` -eq 0 ]]; then
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
  sbi 0x04, 5 /* set DDRB5 in DDRB register to configure PB5 as output */
EOF
if [ "${1}" == "off" ]; then
cat <<EOF
  cbi 0x05, 5 /* clear PORTB5 in PORTB register to keep PB5 low */
EOF
else
cat <<EOF
  sbi 0x05, 5 /* set PORTB5 in PORTB register to drive PB5 high (LED on) */
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
# avrdude version 8.1 is known to work
#
# (by default the LED is turned on by this software)
# (to disable the LED, pass "off" to this script)
# avrdude -c arduino -P /dev/tty.usbserial-0001 -b 115200 \
#         -p atmega328p -D -U flash:w:file.hex:i
