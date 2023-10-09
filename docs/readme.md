# Buddy

Buddy is a general Serial Port and Telnet monitor with many additional features.
In addition to the source code for Buddy, this repository includes a
[**Windows Installer**](https://github.com/phorton1/base-Pub-buddy/tree/master/releases)
to install a completely ready to run version of the program on any *Microsoft Windows*
machine. Buddy is completely *Open Source Pure Perl*. Some key features of
Buddy include:

- displays **ANSI colors**
- works with the **Arduino IDE** and it's build process
- does automatic *rPi* binary *kernel.img* uploads to the
  [**circle-bootloader**](https://github.com/phorton1/circle-prh/tree/master/bootloader)
- works as a
  [*fileServer*](https://github.com/phorton1/base-Pub/tree/master/FS) to the
  [**fileClient**](https://github.com/phorton1/base-Pub-fileClient) Windows application
  that is automatically installed along with Buddy


Buddy is built around the Windows Console (Dos Box) and can display ANSI colors
encoded as escape sequences.  Buddy intercepts various CTRL key combinations,
like CTRL-C to exit, and CTRL-D to clear the screen. Apart from these special
CTRL sequences, everything else that is typed in is sent to the COM
(or Telnet) port unchanged.

Buddy started life as a substitute for the Arduino IDE Serial Monitor. Buddy can
monitor the IDE and close and re-open the COM port as necessary to enable the Arduino
IDE to upload code over the COM Port during a build.

Buddy also very specifically can upload rPi *kernel.img* files to a Raspberry Pi running
my bare-metal
[rPi bootloader]((https://github.com/phorton1/circle-prh/tree/master/bootloader)),
which is part of the
[rPi circle-prh](https://github.com/phorton1/circle-prh) bare-metal OS effort,
from which I developed the
[**Audio Looper**](https://github.com/phorton1/circle-prh-apps-Looper)
box and application that I use with my electric guitar for live looping.

The Windows installation of Buddy.exe also includes the installation of
[**fileClient.exe**](https://github.com/phorton1/base-Pub-fileClient), which
can work with Buddy to provide a nice Windows application
to transfer files to and from the SD Card on *Arduino-like* devices. This
ability was *specifically built* to allow the transfer of **rig files** to
and from the
[**teensyExpression**](https://github.com/phorton1/Arduino-teensyExpression) pedal,
which in turn, also works closely with the
[Looper](https://github.com/phorton1/circle-prh-apps-Looper) in my live performance setup.



## Command Line

As a simple example, the following command line opens Buddy to COM3 at 115200 baud,
and watches out for Arduino IDE builds:

	> buddy 3 115200 -arduino

At least one of the following four options **must** be provided:

- **COM_PORT** - a number by itself on the command line that is less than 100
- **IP_ADDRESS[:PORT]** - something that looks '192.168.0.100' with an optional colon and port number
- **-auto** - tells buddy to try to find a COM port to open and/or use SSDP to find a network (myIOT) device to connect to
- **-auto_no_remote** - auto without the SSDP search

The **default command line** for the *installed* version of Buddy is **-auto**.
The rest of the command line optiona include:

- **BAUD_RATE** - a number like *9600* or *115200*, defaults to 115200
- **-crlf** - outputs the CR or LF as needed when it receives only one of them from the port
- **-arduino** - watches for Arduino IDE builds and temporarily closes the COM port while they are happening
- **-rpi** - turns on the **rPi kernel auto-uploading** feature, described below
- **-file_server** - turns on the *Serial File Server* feature to work with the **fileClient** as described here
- **-file_client** - starts the **fileClient** automatically after starting the *Serial File Server*.


## Automatic Searching for COM Ports and Network Devices

If **-auto** is specified on the command line, buddy will look for any
COM ports and/or SSDP (network) devices that it can connect to.  The
details of how those searches happen can be found in
[ComPorts.pm](https://github.com/phorton1/base-Pub/tree/master) and
[SSDPScan.pm](https://github.com/phorton1/base-Pub/tree/master).

The order of priorities is as follows:

- if Buddy finds a **teensyExpression** on a COM port, it will
  open that COM port add "**-file_server**" to the command line.
- If Buddy finds a **Arduino-like** device on a COM PORT, which
  includes most Arduinos and compatibles, ESP32s, teensies, and so on,
  it will open that COM port and add "**-arduino -crlf**" to the command
  line.
- If Buddy finds a
  [**myIOTDevice**](https://github.com/phorton1/Arduino-libraries-myIOT)
  via SSDP, which would include any of my
  [Clocks](https://github.com/phorton1/Arduino-theClock3) and the
  [bilgeAlarm[(https://github.com/phorton1/Arduino-bilgeAlarm), it
  will open a *telnet* session to the device by adding the appropriate
  "**IP_ADDRESS[:PORT] -crlf**" to the command line.
- And finally, if nothing else has been found, and Buddy finds
  **any open COMM port**, it will open just open that at the
  default BAUD_RATE.

If **-auto** is used, and Buddy can find nothing to connect to,
it will **exit**.

## fileServer and fileClient

## rPi Kernel upload feature

## Summary of CTRL Keys


## Design Details

Please see the [**Design Document**](design.md) for more detailed information about Buddy.

## License

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License Version 3 as published by
the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

Please see **LICENSE.TXT** for more information.

-- end of readme&#46;md --
