#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-adafruit-kb2040-rp2040.sh (super simple sample code)
# this code for "Adafruit KB2040" turns on the NEOPIXEL on GPIO17
# more information is available at https://www.adafruit.com/product/5302
#
# Copyright (C) 2026 Magnus Damm
#
# this script builds some bundled tiny example code to generate
# a binary which may be used to test execution on the target
# see further down in the file for some ARM assembly source code
#
# set CROSS_COMPILE to point out the toolchain
# gcc-arm-none-eabi-6-2017-q2-update is known to work

# makes use of a rp2040 (with a Cortex-M0+)
BINUTILS_OPTS="-march=armv6s-m"

# Probe for required software components
for e in bc cat cut grep head mktemp od rev rm tr uuencode wc which xxd \
	    ${CROSS_COMPILE}as ${CROSS_COMPILE}objcopy
do
    if [ -z `which $e` ]; then
        echo "unable to detect required software component $e, exiting" >&2
        exit 1;
    fi
done

# Check that CROSS_COMPILE actually points to an assembler for ARM
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

# High-compatibility decimal byte-stream processor (thanks to gemini)
_crc32 ()
{
  file="$1"
  crc=4294967295
  poly=3988292384

  # Use od to get decimal bytes, then loop through them
  for byte in $(od -An -v -tu1 "$file"); do
    # Calculate next CRC state using bc
    crc=$(echo "
    define xor(a, b) {
    auto res, i, p; res=0; p=1
    for (i=0; i<32; i++) {
    if ((a%2) != (b%2)) res += p
    a /= 2; b /= 2; p *= 2
    }
    return res
    }
    c = xor($crc, $byte)
    for (i=0; i<8; i++) {
    if (c % 2 == 1) c = xor(c / 2, $poly) else c = c / 2
    }
    print c
    " | bc)
  done

  # Final XOR and Hex output
  echo "obase=16; define xor(a, b) {
  auto res, i, p; res=0; p=1
  for (i=0; i<32; i++) {
  if ((a%2) != (b%2)) res += p
  a /= 2; b /= 2; p *= 2
  }
  return res
  }
  xor($crc, 4294967295)" | bc
}

bitrev ()
{
  xxd -b -c1 | cut -f 2 -d " " | rev | \
    while read rev_byte
    do
      echo "0: ${rev_byte}" | xxd -r -b
    done
}

invert ()
{
  xxd -b -c1 | cut -f 2 -d " " | \
    while read byte
    do
      inv_byte=`echo ${byte} | tr 0 x | tr 1 0 | tr x 1`
      echo "0: ${inv_byte}" | xxd -r -b
    done
}

eight_chars ()
{
   echo 00000000${1} | rev | head -c 8 | rev
}

# turn on break-on-failure
set -e

emit_asm () {
  cat <<EOF
  .syntax unified

  .thumb
  .thumb_func
  .text
  .align 1
  .global _start
  .type _start, %function
_start:
  /* initialize GPIO17 as output for WS2812B-2020 control */

  ldr r0, =0x00000120 /* PADS_BANK0 + IO_BANK0 */
  ldr r5, =(0x4000c000 + 0x3000) /* RESET_RESETS (CLR alias) */
  str r0, [r5]

  movs r0, #5
  ldr r5, =(0x4001408c + 0x0000) /* GPIO17_CTRL (normal alias) */
  str r0, [r5]

  ldr r0, =(1 << 17) /* GPIO17 */
  ldr r5, =(0xd0000024 + 0x0000) /* GPIO_OE_SET (normal alias) */
  str r0, [r5]

  /* generate a waveform for WS2812B-2020 */
  /* 1 x 300us reset */
  /* 24 x ( T1H (740ns) + T1L (370ns) ) */

  ldr r5, =(0xd0000014 + 0x0000) /* GPIO_OUT_SET (normal alias) */
  ldr r6, =(0xd0000018 + 0x0000) /* GPIO_OUT_CLR (normal alias) */

  movs r3, #1  /* first run one dummy change */
  movs r4, #2  /* reset + second run when cached */

  str r0, [r5] /* low to high (initial setup, end of T0H, start of T1H) */
loop:
  str r0, [r6] /* clear or toggle */
  nop
loop2:
  str r0, [r6] /* clear or toggle */
  subs r3, #1
  bne loop

  ldr r2, =410  /* duration of a 300 us reset pulse */ 
dly:
  subs r2, #1
  bne dly

  ldr r6, =(0xd000001c + 0x0000) /* GPIO_OUT_XOR (normal alias) */
  movs r3, #25 /* generate 24 identical pulses */
  subs r4, #1
  bne loop2

end:
  b end

  .align 2
  .pool
EOF
}

# generate a binary from the source, store padded result in FIRST_252
emit_asm | ${CROSS_COMPILE}as ${BINUTILS_OPTS} -mlittle-endian -o "${t1}"
${CROSS_COMPILE}objcopy "${t1}" -O binary "${t0}"
dd if="${t0}" bs=252 count=1 conv=sync of="${t1}" 2> /dev/null
FIRST_252=`cat "${t1}" | xxd -ps`

# checksum needs to be present for the bootrom to accept the code
cat "${t1}" | bitrev > "${t0}" # bitrev the payload before checksumming
CRCN=`_crc32 "${t0}"` # calculate a regular CRC32
CRC8=`eight_chars "${CRCN}"` # force 8 characters to work with leading zeroes
CRC=`echo "${CRC8}" | xxd -r -ps | bitrev | invert | xxd -ps` # rev, inv

# code is in little endian, store checksum in big endian
( echo ".long 0x${CRC}"; ) \
 | ${CROSS_COMPILE}as ${BINUTILS_OPTS} -mbig-endian -o "${t0}"
${CROSS_COMPILE}objcopy "${t0}" -O binary "${t1}"

# uuencode padded code followed by checksum to stdout (used as file.uue below)
( echo "${FIRST_252}" | xxd -r -ps; cat "${t1}" ) | uuencode -

# use picotool to program the device over USB
# picotool v2.2.0 is known to work
#
# (to clear the device of any user software use "picotool erase")
# (in the erased state the LED is off by default)
#
# (program the teeensy code to turn on the LED like this to address 0x10000000)
# cat file.uue | uudecode -o /dev/stdout > file.bin
# picotool load -t bin file.bin
#
# (the device needs to be put into BOOTSEL mode before invoking picotool)
# (press SW2 /RESET to force a reset which turns on the LED)
