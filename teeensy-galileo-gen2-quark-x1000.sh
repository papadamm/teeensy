#!/bin/sh
# SPDX-License-Identifier: MIT
#
# teeensy-galileo-gen2-quark-x1000.sh (super simple sample code)
# this code for Intel Galileo Gen2 will control the SD_LED
#
# Copyright (C) 2026 Magnus Damm
#
# this script builds some bundled tiny example code to generate a binary
# which may be used to test execution on the target, see further
# down in the file for some x86 assembly source code
#
# set CROSS_COMPILE to point out the toolchain
# i386-unknown-elf from binutils-2.47 is known to work
#
# omitting CROSS_COMPILE may also work out of the box with CLANG
# for instance on Mac OS X (Apple clang version 15.0.0 (clang-1500.3.9.4))

# Intel Galileo Gen2 (Intel Quark SoC X1000 with i586 core)
CLANG_OPTS="--target=x86 -mcpu=i586"
BINUTILS_OPTS="-march=i586"

# Probe for required software components
for e in cat grep mktemp rm wc which ${CROSS_COMPILE}as ${CROSS_COMPILE}objcopy
do
    if [ -z `which $e` ]; then
        echo "unable to detect required software component $e, exiting" >&2
        exit 1;
    fi
done

# Check that CROSS_COMPILE actually points to an assembler for i586
AS_OPTS=${CLANG_OPTS}
${CROSS_COMPILE}as ${CLANG_OPTS} /dev/null -o /dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    AS_OPTS=${BINUTILS_OPTS}
    ${CROSS_COMPILE}as ${BINUTILS_OPTS} /dev/null -o /dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
	echo "Failed to detect i586 support in CROSS_COMPILE, exiting" >&2
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

output_asm ()
{
cat <<EOF
  .text
  .code32
  .global _start
  /* .type _start, %function */
_start:
  /* turning on a LED is not that difficult it seems. */
  /* set SD_LED output to 1 via bit 0 of HOST_CTL of the SD-Card controller */
  /* this assumes a preconfigured PCI BAR for Bus 0, Device 0, Function 0 */
  /* using OpenOCD the BAR for the SD-Card controller can be verified using */
  /* "x86_32 iww 0xcf8 0x8000a010" followed by "x86_32 idw 0xcfc" */
  /* the above should read out 0x90010000, add 0x28 for HOST_CTL */
  /* in OpenOCD use "mwb 0x90010028 0x1" to set bit 0 to enable the LED */

  /* regarding load address, how to locate the eSRAM remains to be seen */
  /* same goes with programming the flash. until that becomes clear, */
  /* it seems it is possible to load code into registers of some I/O device */
  /* like registers of the "Legacy SPI" device. determine or setup RCBA by */
  /* reading PCI space at 0xe00f80f0, this might be setup as 0xfed1c001 */
  /* then masking and adding into base address 0xfed1f028 (SPI Data 0..) */
  /* it is possible to perform "load_image file.hex 0xfed1f028" however */
  /* this seems to depend on the state of the system, pushing REBOOT */
  /* after halt seems to gives EIP in the BIOS range, protected mode */

  /* position independent code below */
  /* disassmble with i386-unknown-elf-objdump -b binary \ */
  /* -m i386 -M i386,data32,intel -D file.bin */

  movl 0x90010028, %edx
  mov 0x01, %al
  mov %al, (%edx)

end:
  jmp end
EOF
}

output_asm $1 | ${CROSS_COMPILE}as ${AS_OPTS} -o "${t1}"
${CROSS_COMPILE}objcopy "${t1}" -O ihex "${t0}"
cat "${t0}" # the contents come out on stdout, used as "file.hex" below

# example using Segger J-Link Ultra 20-pin JTAG to Intel Galileo Gen2 J2 port
#
# please note that even though the form factor of the on-board JTAG port is
# matching a standard mini-10 pin JTAG port, the actual pinout differs from
# mini-10 used on ARM platforms such as Arduino Due and GR-MANGO. Because of
# this using a common adapter from 20-pin JTAG to ARM mini-10 will not work.
#
# Here is how to work around this issue with a breakout adapter and wires.
#
# Known to work configuration using a female 20-pin JTAG port (on a J-Link)
# with loose Dupont Wires to an Adafruit SWD breakout adapter and from there
# a regular mini-10 ribbon cable to the target board J2 connector.
#
# (20-pin JTAG - SWD Breakout - 10-pin MINI-JTAG)
# Power and Ground: 1:VTref - 1:Vref - 1:VCC , 4:GND - 3:GND - 3:GND
# Debug port: 5:TDI - 8:NC - 8:TDI, 7:TMS - 2:SWDIO - 2:TMS
# Debug port: 9:TCK - 4:CLK - 4:TCLK, 13:TDO - 6:SWO - 6: TDO
# (Optional) Reset: 15:RESET - 10:/RST - 10:RESET
# 
# Furthermore, recent openocd releases seem to have broken x1000 support.
#
# Support for x1000 to openocd was added by the following git commit:
# 1338cf60b quark_x10xx: add new target quark_x10xx
#
# Partial trial and error with building a custom openocd binary on Mac OS X:
# % ./configure --prefix=../install-v0.8.0 --disable-aice \
# --disable-usb-blaster-2 --disable-ulink --disable-armjtagew
#
# Once the code has been built, this is how to invoke it for x1000:
#
# openocd -f interface/jlink.cfg  -f board/quark_x10xx_board.cfg \
# 	-c "adapter_khz 1000; reset_config trst_only"
#
# If the JTAG wires are correctly hooked up you will see something like this:
# Open On-Chip Debugger 0.8.0-dirty (2026-04-30-15:47)
# Licensed under GNU GPL v2
# For bug reports, read
# 	http://openocd.sourceforge.net/doc/doxygen/bugs.html
# Info : only one transport option; autoselect 'jtag'
# adapter speed: 4000 kHz
# trst_only separate trst_push_pull
# adapter speed: 1000 kHz
# trst_only separate trst_push_pull
# Info : J-Link initialization started / target CPU reset initiated
# Info : J-Link Ultra V5 compiled Aug 24 2020 10:18:43
# Info : J-Link caps 0xb9ff7bbf
# Info : J-Link hw version 7050000
# Info : J-Link hw type uknown 0x7
# Info : J-Link max mem block 237392
# Info : J-Link configuration
# Info : USB-Address: 0x0
# Info : Kickstart power on JTAG-pin 19: 0xffffffff
# Info : Vref = 3.349 TCK = 1 TDI = 0 TDO = 1 TMS = 0 SRST = 0 TRST = 0
# Info : J-Link JTAG Interface ready
# Info : clock speed 1000 kHz
# Info : JTAG tap: quark_x10xx.cltap tap/device found: 0x0e681013 \
#	(mfg: 0x009, part: 0xe681, ver: 0x0)
# enabling core tap
# Info : JTAG tap: quark_x10xx.cpu enabled
