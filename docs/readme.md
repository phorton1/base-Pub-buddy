# Buddy

Buddy is a general Serial Port and Telnet monitor with many additional features.
In addition to the source code for Buddy, this repository includes a
[**Windows Installer**](https://github.com/phorton1/base-Pub-buddy/tree/master/releases)
to install a completely ready-to-run version of the program on any *Microsoft Windows*
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

Here is a screenshot of Buddy connected to the
[teensyExpression pedal](https://github.com/phorton1/Arduino-teensyExpression)
showing the output from Buddy itself in **white**, and showing the debugging
output from TE in <font color='green'><b>green</b></font> with a *Warning*
shown in <font color='gold'><b>yellow</b></font>:

![buddy-teensyExpression.jpg](images/buddy-teensyExpression.jpg)

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
[rPi bootloader](https://github.com/phorton1/circle-prh/tree/master/bootloader),
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
  [bilgeAlarm](https://github.com/phorton1/Arduino-bilgeAlarm), it
  will open a *telnet* session to the device by adding the appropriate
  "**IP_ADDRESS[:PORT] -crlf**" to the command line.
- And finally, if nothing else has been found, and Buddy finds
  **any open COMM port**, it will open just open that at the
  default or given BAUD_RATE.

If **-auto** is used, and Buddy can find nothing to connect to,
it will **exit**.

## Summary of CTRL Keys

While you are connected to a device with Buddy, certain **CTRL** keys
will be intercepted by Buddy and **not sent** to the device. Here is
a list of the CTRL keys that Buddy responds to

- **CTRL-C** - exits Buddy
- **CTRL-D** - clears the Screen
- **CTRL-E** - pops up the [fileClient](https://github.com/phorton1/base-Pub-fileClient)
  if using **-file_server** or **-file_client** command line options
- **CTRL-X** - initiates an **upload** of a *kernel.img* to the
  [**rPi**](https://github.com/phorton1/circle-prh/tree/master/bootloader) \
  if using the **-rpi** command line option


## the fileClient

When you install Buddy with the
[Windows Installer](https://github.com/phorton1/base-Pub-buddy/tree/master/releases),
it also installs an executable (EXE) for the [fileClient](https://github.com/phorton1/base-Pub-fileClient).

Although the *fileClient* is a stand-alone general purpose **User Interface** to any
*fileServer* implemented using my [Pub::FS](https://github.com/phorton1/base-Pub/tree/master/FS)
architecture, it has a special relationship to Buddy.  If you had connected to the
[teensyExpression](https://github.com/phorton1/Arduino-teensyExpression) pedal, as
shown in the *above example window*, and then pressed **CTRL-E** (or had specified
**-file_client** on the command line) the fileClient would **pop up** looking something
like this:

![fileCliient-local-TE.jpg](images/fileCliient-local-TE.jpg)

This window allows you to transfer files to and from the your *Windows* machine
(from the **/junk/data** directory) to the *SD Card* in the
[teensyExpression](https://github.com/phorton1/Arduino-teensyExpression).
The *left* pane shows the files on the Windows machine and the *right*
pane shows the files on the SD Card.

Files that have the same *timestamp and size* are shown in <font color='blue'><b>blue</b></font>.

In this example, the file **default_modal.rig** on the Windows machine is
**newer** than the one on the SDCard, and
shown in <font color='red'><b>red</b></font>, whereas the file on the SD Card
is **older** and shown in <font color='magenta'><b>magenta</b></font>.
This use of **colors** allows you to easily identify files that need
to be transferred from one machine to the other.  By **right clicking**
on the *default_mnodal.rig* file you can select *Transfer* to 'upload'
the file from the Windows machine to the SDCard in the teensyExpression.

Please see the [documentation](https://github.com/phorton1/base-Pub-fileClient)
on the **fileClient** for more detailed information on how to use it.



## rPi Kernel upload feature




## Perl and Design Details

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

---- end of readme ----
