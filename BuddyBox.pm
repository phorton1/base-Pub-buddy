# Buddy - a Putty like Telnet CONSOLE with a fileClient window
#
# command line
#
#   auto == let buddy figure out the best port/ip to use
#
#   COM port number or IP addresss MUST be provided if not AUTO
#
#      If an IP address is provided, it may optionally include a port
#
#             192.168.0.123:80
#
#      If no port is specified the default TELNET 23 port will be used.
#
#   default baud = 115200
#
#   Any number by itself on the command line that is less than 100 is considered a COM port number
#   Any number by itself on the command line that is geq 100 is considered a baud rate
#
#   -crlf  will send crlf when cr is typed (the default of the console
#          is to return one character for each keystroke) and will
#          echo the characters that are typed on the local screen
#          it is usually up to the client to echo characters,
#          but sometimes it's useful to see what's being typed
#
#   -arduino   watches for arduino builds and disconnects the comm port
#              while the build is active, and reconnects 2 seconds after
#              it finishes
#
#   -rpi       watches for kernel changes and uploads new kernels to the rPi automatically
#              allows for ^X to upload the kernel manually. Also turns on magic CTRL-A
#			   for teensyPiLooper for -file_server.
#
#   -file_server   for use currently only with teensyExpression, starts a
#          buddy_FileServer which can be hit with my fileApplication over a
#          localhost port to allow for manipulating the files on the
#          teensyExpression 3.6 SD Card.
#
#          If going through teensyPiLooper -rpi MUST be set to send magic CTRL-A !!
#
#		   Note also that if the TE is hooked directly to the laptop (not
#          going through teensyPiLooper), the CTRL-A that is sent will
#          generate a 'broken serial midi" error message, but everything
#          seems to still work.  Nonetheess, it is best to use -rpi when
#          going through the teensyPiLooper, and best to NOT use it when
#          the TE is directly attached to the laptop.
#
#--------------------------------------------------------------------------
# Generalized rPi auto-upload scheme for use with my Circle bootloader
#--------------------------------------------------------------------------
# The system reads, and watches for, changes to a file called
# /base/bat/console_autobuild_kernel.txt.
#
# This file contains a single line specifying a kernel.img to be uploaded
# to the rPi, ie:  /src/Arduino/_circle/audioDevice/kernel7.img
#
# This file is uploaded when -upload and ctrl-X is pressed, or
# or when the console_autobuild_kernel.txt changes,
# or the file it points to changes. When this happens the rPi will
# be rebooted and when the console sees the $KERNEL_UPLOAD_RE,
# it will upload the given kernel.img to the bootloader.
#
#------------------------------------------
# interaction with KOMODO keystroke macros
#------------------------------------------
#
#   ctrl-O = clean a bare metal project directory
#       calls clean_rpi.js komodo script (nothing to do with buddy)
#   ctrl-J = build the left most kernel.cpp
#       calls compile_rpi.js komodo script
#
#       executes a make in the directory containing the
#       left most kernel.cpp file.  If the first time per
#       komodo invocation, or if the kernel.cpp is different
#       than the previous build, komodo writes a new
#       /base/bat/console_autobuild_kernel.txt pointing
#       to the new kernel.img.  The rest happens here.
#
#   ctrl-K = build the circle/_prh/bootloader/recovery.img
#       calls compile_bootloader.js komodo script
#       (nothing to do with buddy)
#
#       at this time there is no automatic upload, or indeed,
#       no soft upload of recovery.img to the SD card.  For
#       build/test cycles of the bootloader, the makefile needs
#       to be modified to produce kernel.img instead of recovery.img
#       and ctrl-J used.  Usually, ctrl-K is used in conjunction with
#       ctrl-L build/test cycles with SD card swapping.
#
#   ctrl-L = used to update the rpi SD memory card
#       in the laptop memory card slot (nothing to do with buddy)


use strict;
use warnings;
use threads;
use threads::shared;
use Cava::Packager;
use Socket;
use Time::HiRes qw( sleep usleep  );
use Win32::Console;
use Win32::Process::List;
use Win32::Process::Info qw{NT};
use Win32::SerialPort qw(:STAT);
use IO::Socket::INET;
use Net::Telnet;
use Pub::Utils;
use Pub::ComPorts;
use Pub::SSDPScan;
use Pub::FS::RemoteServer;
use Pub::FS::SessionRemote;
use Pub::buddy::buddy_Colors;
use Pub::buddy::buddy_Binary;
use Pub::buddy::buddy_Grab;


my $dbg_fileserver = 0;
	# 0 = show file commands sent and replies recieved
	# -1 = show debuffered file replies
my $dbg_auto = 0;


$| = 1;     # IMPORTANT - TURN PERL BUFFERING OFF MAGIC

my $SSDP_TIMEOUT = 15;

my $TELNET_PORT = 23;
	# Default TCP/IP port is TELNET.
	# Somewhere I have a server on port 80

my $DEFAULT_BAUD_RATE = 115200;
my $SYSTEM_CHECK_TIME = 3;
    # check for changed COM/SOCKET connections and, for rpi,
	# new kernel.img every this many seconds

my $ARDUINO_PROCESS_NAME = "arduino-builder.exe";
my $KERNEL_UPLOAD_RE = 'Press <space> within \d+ seconds to upload file';


# Filename constants

my $upload_spiffs_sempaphore_file = "/junk/in_upload_spiffs.txt";
	# a file to act as a semaphore to disonnect the com port, like we
	# do with an Arduino compile process, when upload_spiffs.pm
	# is called from Komodo
my $registry_filename = "/base/bat/console_autobuild_kernel.txt";
my $registry_filetime = getFileTime($registry_filename);




#-----------------------
# command line params
#-----------------------

my $COM_PORT = 0;
my $BAUD_RATE = $DEFAULT_BAUD_RATE;

my $auto = 0;
my $crlf = 0;
my $rpi = 0;
my $arduino = 0;
my $sock_ip = '';
my $sock_port = 0;
my $file_server = 0;
my $start_file_server = 0;


#-----------------------
# working variables
#-----------------------

my $con = Win32::Console->new(STD_OUTPUT_HANDLE);
my $in = Win32::Console->new(STD_INPUT_HANDLE);
$in->Mode(ENABLE_MOUSE_INPUT | ENABLE_WINDOW_INPUT );
$con->Attr($COLOR_CONSOLE);

my $port;
my $sock;
my $in_arduino_build:shared = 0;
my $ssdp_found:shared = '';

my $kernel_filename = '';
my $kernel_filetime = 0;
my $kernel_file_changed = 0;



#---------------------------------------------------
# process Command Line
#---------------------------------------------------

$con->Title("initializing ...");

# parse command line

my $arg_num = 0;
while ($arg_num < @ARGV)
{
    my $arg = $ARGV[$arg_num++];
    if ($arg =~ /^-(.*)/)
    {
		my $val = $1;
		if ($val eq 'auto')
		{
			$auto = 1;
		}
		elsif ($val eq 'rpi')
		{
			$rpi = 1;
		}
		elsif ($val eq 'crlf')
		{
			$crlf = 1;
		}
		elsif ($val eq 'arduino')
		{
			$arduino = 1;
		}
		elsif ($val eq 'file_server')
		{
			$start_file_server = 1;
		}
		else
		{
			print "Illegal command line argument: -$arg\n";
			exit 0;
		}

    }
    elsif ($arg =~ /^\d+$/)
    {
        if ($arg >= 100)
        {
            $BAUD_RATE = $arg;
        }
        else
        {
            $COM_PORT = $arg;
        }
    }
	elsif ($arg =~ /^(\d+\.\d+\.\d+\.\d+)(:(\d+))*$/)
	{
		# Port 23 works with my ESP32 Telnet
		# somewhere I have an implementation using port 80

		($sock_ip,$sock_port) = ($1,$3);
		$sock_port ||= $TELNET_PORT;

		# default to echo/crlf

		$crlf = 1;
	}
}


checkAuto() if $auto;

if (!$COM_PORT && !$sock_ip)
{
	error($auto ?
		  "Could not find any ports or remote devices to connect to!" :
		  "PORT or IP address must be specified!!");
	print "Hit any key to close window -->";
	getc();
	exit(0);
}

print "-rpi\n" if ($rpi);
print "-crlf\n" if ($crlf);
print "-arduino\n" if $arduino;
print "-file_server\n" if $start_file_server;

if ($sock_ip)
{
	print "SOCKET: $sock_ip:$sock_port\n";
}
else
{
	print "COM$COM_PORT at $BAUD_RATE baud\n";
}


if ($start_file_server)
{
	my $params = $COM_PORT ? { PORT => $DEFAULT_PORT + $COM_PORT } : '';
	$file_server = Pub::FS::RemoteServer->new($params);
}


#--------------------------------------------------
# checkAuto
#--------------------------------------------------


sub onSSDPDevice
{
    my ($rec) = @_;
    if (!$ssdp_found)
    {
		my $iot_device = $rec->{SERVER} =~ /myIOTDevice UPNP\/1.1 (.*)\// ? $1 :
			$rec->{SERVER} ? $rec->{SERVER} :
			$rec->{ST} ? $rec->{ST} :
			"unknown device";
	    display($dbg_auto,0,"onSSDPDevice($rec->{ip}) = $iot_device");
		$ssdp_found = shared_clone([$rec->{ip}, $iot_device]);
    }
}


sub checkAuto
{
	my $started = Pub::SSDPScan::start($SEARCH_MYIOT,\&onSSDPDevice,28);
	my $ports = Pub::ComPorts::find();
	my $ssdp_started = time();

	if ($ports)
	{
		my $found_any = '';
		my $found_TE = '';
		my $found_arduino = '';
		for my $port (keys %$ports)
		{
			my $rec = $ports->{$port};
			$found_any ||= $rec;
			$found_TE = $rec if $rec->{midi_name} eq "teensyExpressionv2";
			$found_arduino = $rec if $rec->{device} =~ /teensy|arduino|esp32/i;
		}

		if ($found_TE)
		{
			print "found TE $found_TE->{device} on COM$found_TE->{num}\n";
			$arduino = 1;
			$start_file_server = 1;
			$COM_PORT = $found_TE->{num};
		}
		elsif ($found_arduino)
		{
			print "found ARDUINO $found_arduino->{device} on COM$found_arduino->{num}\n";
			$arduino = 1;
			$crlf = 1 if $found_arduino->{device} =~ /ESP32/i;
			$COM_PORT = $found_arduino->{num};
		}
		elsif ($found_any)
		{

			print "found COM$found_any->{num} VID($found_any->{VID}) PID($found_any->{PID})\n";
			$COM_PORT = $found_any->{num};
		}
		else
		{
			my $now = time();
			while (!$ssdp_found && $now < $ssdp_started + $SSDP_TIMEOUT)
			{
				my $secs = $SSDP_TIMEOUT - ($now - $ssdp_started);
				print "Searching for remote devices($secs) ...\n";
				sleep(2);
				$now = time()
			}
			if ($ssdp_found)
			{
				print "found REMOTE $ssdp_found->[1] at $ssdp_found->[0]\n";
				$sock_ip = "$ssdp_found->[0]:$TELNET_PORT";
				$crlf = 1;
			}
		}
	}

	Pub::SSDPScan::stop() if $started;
}



#---------------------------------------------------
# methods
#---------------------------------------------------

sub getFileTime
{
    my ($filename) = @_;
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
	  	$atime,$mtime,$ctime,$blksize,$blocks) = stat($filename);
    # print "file_time=$mtime\n";
    return $mtime || 0;
}


sub getChar
{
    my (@event) = @_;
    if ($event[0] &&
        $event[0] == 1 &&       # key event
        $event[1] == 1 &&       # key down
        $event[5])              # char
    {
        return chr($event[5]);
    }
    return undef;
}


sub isEventCtrlC
    # my ($type,$key_down,$repeat_count,$key_code,$scan_code,$char,$key_state) = @event;
    # my ($$type,posx,$posy,$button,$key_state,$event_flags) = @event;
{
    my (@event) = @_;
    if ($event[0] &&
        $event[0] == 1 &&      # key event
        $event[5] == 3)        # char = 0x03
    {
        print "ctrl-C pressed ...\n";
        return 1;
    }
    return 0;
}


sub getKernelFilename
{
	if (!open(IFILE,"<$registry_filename"))
	{
		printf("ERROR - could not open registry_file $registry_filename for reading!\n");
	}
	else
	{
		$kernel_filename = <IFILE>;
		$kernel_filename =~ s/\s+$//g;
		$kernel_filename =~ s/\\/\//g;
		close IFILE;
		printf "got kernel filename=$kernel_filename\n";
	}
}


sub showStatus
{
	my $title = "";
	$title .= $sock_ip ? "$sock_ip:$sock_port" : "COM$COM_PORT ";
	$title .= " CONNECTED" if $port || $sock;
	$title .= " -crlf" if $crlf;
	$title .= " -arduino" if $arduino;
	$title .= " IN_BUILD" if $in_arduino_build;
	$title .= " -file_server " if ($start_file_server);
	$title .= " -rpi $kernel_filename" if $rpi;
	$con->Title($title);
}


sub connectSocket
{
	print "Connecting TCP/IP to $sock_ip:$sock_port\n";
	my @psock = (
		PeerAddr => $sock_ip,
		PeerPort => $sock_port, # "udp(80)",         #  "http(80)",
		Proto    => 'tcp',      # 'udp'
		Timeout  => 5,          # timeout for connection
		Blocking => 0,
		# KeppAlive  => 1,
	);
	$sock = IO::Socket::INET->new(@psock);
	if (!$sock)
	{
		print("ERROR could not connect to TCP/IP server\n");
	}
	else
	{
		# setsockopt($sock, SOL_SOCKET, SO_KEEPALIVE, 1);
		print "Connected to TCP/IP $sock_ip:$sock_port\n";
		binmode $sock;
		$sock->blocking(0);
	}
	showStatus();
}


sub initComPort
{
    # print "initComPort($name,$com_port,$baud_rate)\n";

	return if $sock_ip;

    $port = Win32::SerialPort->new("COM$COM_PORT",1);

    if ($port)
    {
        print "COM$COM_PORT opened\n";

        # This code modifes Win32::SerialPort to allow higher baudrates

        $port->{'_L_BAUD'}{78440} = 78440;
        $port->{'_L_BAUD'}{230400} = 230400;
        $port->{'_L_BAUD'}{460800} = 460800;
        $port->{'_L_BAUD'}{921600} = 921600;
        $port->{'_L_BAUD'}{1843200} = 1843200;

        $port->baudrate($BAUD_RATE);
        $port->databits(8);
        $port->parity("none");
        $port->stopbits(1);

        # $port->buffers(8192, 8192);
        $port->buffers(60000,8192);

        $port->read_interval(100);    # max time between read char (milliseconds)
        $port->read_char_time(5);     # avg time between read char
        $port->read_const_time(100);  # total = (avg * bytes) + const
        $port->write_char_time(5);
        $port->write_const_time(100);

        $port->handshake("none");   # "none", "rts", "xoff", "dtr".
			# handshaking needed to be turned off for uploading binary files
            # or else sending 0's, for instance, would freeze

		# $port->dtr_active(1);
        # $port->binary(1);

        if (!$port->write_settings())
        {
            print "Could not configure COM$COM_PORT\n";
            $port = undef;
        }
        else
        {
            $port->binary(1);
            showStatus();
        }
    }
    return $port;
}



sub systemCheck
{
    # print "system check ...\n";
    # check for dropped ports

    if ($port)
    {
        my ($BlockingFlags, $InBytes, $OutBytes, $LatchErrorFlags) = $port->status();
        if (!defined($BlockingFlags))
        {
            # $save_port = $port;
            # save the port to prevent reporting of errors
            # when Win32::SerialPort tries to close it when
            # we set it to undef below.  So far, no negative
            # side effects from this ...

            print "COM$COM_PORT disconnected\n";
            $port = undef;
            showStatus();
        }
    }
	elsif ($sock)
	{
		$sock->write(chr(0));
			# send a null character for keep alive
	}

    # check if the kernel registry file has changed and update
	# the kernel filename if it has ...

    if ($rpi)
    {
        my $check_time = getFileTime($registry_filename);
		if ($check_time != $registry_filetime)
		{
			$registry_filetime = $check_time;
			print "kernel registry file has changed\n";
			if ($check_time)
			{
				my $save_kernel_filename = $kernel_filename;
				getKernelFilename();
				if ($kernel_filename ne $save_kernel_filename)
				{
					print "kernel_filename changed to $kernel_filename\n";
					$kernel_filetime = 0;	# will always upload it if auto_upload
				}
			}
			else
			{
				print "WARNING: $registry_filename disappeared!\n";
			}
		}

		$check_time = getFileTime($kernel_filename);
		if ($check_time != $kernel_filetime)
		{
			$kernel_filetime = $check_time;
			if ($check_time)
			{
				print "$kernel_filename changed\n";
				$kernel_file_changed = 1;
				if ($port)
				{
					print "AUTO-REBOOTING rpi (sending ctrl-B)\n";
					$port->write("\x02");
					$kernel_filetime = $check_time;
				}
				else
				{
					print "WARNING: cannot reboot rpi - COM$COM_PORT is not open!\n";
				}
			}
			else
			{
				print "WARNING: kernel $kernel_filename not found!\n";
			}
		}
	}

}   # systemCheck()



sub listen_for_arduino_thread
	# watch for a process indicating an Arduino build is happening
	# and set $in_arduino_build if it is
{
    while (1)
    {
		my $found = -f $upload_spiffs_sempaphore_file;
		if (!$found)
		{
			my $pl = Win32::Process::List->new();
			my %processes = $pl->GetProcesses();

			# print "PROCESS::LIST\n";
			foreach my $pid (sort {$processes{$a} cmp $processes{$b}} keys %processes )
			{
				my $name = $processes{$pid};
				# print "$name\n" if $name;
				if ($name eq $ARDUINO_PROCESS_NAME)
				{
					# print "Found process arduino-builder.exe\n";
					$found = 1;
					last;
				}
			}
		}

        if ($found && !$in_arduino_build)
        {
            $in_arduino_build = 1;
            print "in_arduino_build=$in_arduino_build\n";
        }
        elsif ($in_arduino_build && !$found)
        {
			print "in_arduino_build=0 ... sleeping for 2 seconds\n";
            sleep(2);
            $in_arduino_build = 0;
            # print "resuming after sleep\n";
        }

        sleep(1);
    }
}




#==================================================================
# MAIN
#==================================================================

print "Initializing ...\n";


if ($arduino)
{
    my $arduino_thread = threads->create(\&listen_for_arduino_thread);
    $arduino_thread->detach();
}


if ($rpi)
{
	if (!$registry_filetime)
	{
		printf("ERROR - could not open registry_file $registry_filename!\n");
	}
	else
	{
		getKernelFilename();
		if (!$kernel_filename)
		{
			printf("WARNING - no kernel filename found in $registry_filename!\n");
		}
		else
		{
			$kernel_filetime = getFileTime($kernel_filename);
			if (!$kernel_filetime)
			{
				printf("WARNING - kernel $kernel_filename not found!\n");
			}
			else
			{
				print "kernel=$kernel_filename\n";
			}
		}
	}
}



#-------------------------------------------
# readProcessPort()
#-------------------------------------------

my $esc_cmd = '';
my $in_line = '';
my $tmp_file_reply = '';
my $is_esc_line = 0;


sub readProcessPort
{
	my $buf;
	my $bytes;

	if ($port)
	{
		my ($BlockingFlags, $InBytes, $OutBytes, $LatchErrorFlags) = $port->status();
			# print ">$BlockingFlags, $InBytes, $OutBytes, $LatchErrorFlags\n";
			# we differentiate fileSystem replies from regular output
			# teensyEpression output by assuming that regular output always
			# starts with an ESC color sequence.
		($bytes,$buf) = $port->read($InBytes) if $InBytes;
	}
	elsif ($sock)
	{
		$bytes = sysread($sock,$buf,1024);
			# Note that we are writing out a zero in systemCheck() to trigger
			# this error handler.

		if ($! && $! !~ /A non-blocking socket operation could not be completed immediately/)
		{
			# print "ERROR: $!\n";
			printf("SOCKET CONNECTION LOST\n");
			$sock->close();
			$sock = undef;
			showStatus();
			return;
		}
	}

	if (!$bytes)
	{
		return;
	}

	#---------------------------------------
	# process bytes from port or socket
	#---------------------------------------

	for (my $i=0; $i<$bytes; $i++)
	{
		my $c = substr($buf,$i,1);

		if ($in_screen_grab)
		{
			handleScreenGrab($c);
		}
		elsif ($esc_cmd)
		{
			$esc_cmd .= $c;
			if ($esc_cmd =~ /\x1b\[(\d+)m/)
			{
				my $color = $1;
				# print "setting color($color)\n";
				$con->Attr(colorAttr($color));
				$esc_cmd = '';
			}
			if ($esc_cmd =~ /\x1b\[(\d+);(\d+)m/)
			{
				my ($fg,$bg) = ($1,$2);
				$bg -= 10;

				# print "setting color($fg,$bg)\n";
				$con->Attr(colorAttr($bg)<<4 | colorAttr($fg));
				$esc_cmd = '';
			}
			elsif ($esc_cmd =~ /\x1b\[[23]J/)
			{
				$con->Cls();
				$esc_cmd = '';
			}
			elsif (length($esc_cmd) > 9)
			{
				$esc_cmd = '';
			}
		}

		# escape commands cannot be sent in the middle of line

		elsif (!$in_line && ord($c) == 27)
		{
			# print("starting escape command\n");
			$esc_cmd = $c;
			$is_esc_line = 1;
		}

		else  # default character handler
		{
			# we now require crlf to indicate the end of a line

			# under the assumption that no-one will send us a 'command'
			# in the middle of an 'escape line', if this is an 'escape line'
			# we print the individual characters so that we can get
			# progress thingees ...

			if ($is_esc_line)
			{
				print $c;					# including cr and/or lf
				if (ord($c) == 10)			# we have finished the line
				{
					$con->Attr($COLOR_CONSOLE);
					$is_esc_line = 0;
				}
			}

			# otherwise, we build a line into the buffer and deal with it on chr(10)

			elsif (ord($c) == 10)
			{
				# display(0,0,"inline=$in_line");

				if ($in_line =~ /SCREEN_GRAB\((\d+)x(\d+)\)/)
				{
					($grab_width, $grab_height) = ($1,$2);
					$in_screen_grab = $grab_width * $grab_height * 3;

					print("doing SCREEN_GRAB($grab_width X $grab_height) $in_screen_grab bytes\n");

					$screen_grab = '';
					$in_line = '';
				}
				elsif ($file_reply_pending && $in_line =~ s/^file_reply://)
				{
					while ($in_line =~ s/\n|\r//g) {}
					display($dbg_fileserver,0,"file_reply: $in_line");
					$tmp_file_reply .= $in_line."\n";
				}
				elsif ($file_reply_pending && $in_line =~ /^file_reply_end/)
				{
					display($dbg_fileserver+1,0,"setting file_server_reply==>$tmp_file_reply<==");
					display($dbg_fileserver,0,"file_reply end");
					$file_server_reply = $tmp_file_reply;
					$tmp_file_reply = '';
					$file_reply_pending = 0;
				}
				else	# case where a printable line DID NOT start with an escape sequence
				{
					print $in_line."\n";
					$con->Attr($COLOR_CONSOLE);
				}

				$in_line = '';
			}

			elsif (ord($c) != 13)
			{
				$in_line .= $c;
			}


		}	# default character handler
	}	# for each byte

	$con->Flush();

	if ($in_line =~ /\n/)
	{
		if ($kernel_file_changed)
		{
			my $do_upload = ($in_line =~ $KERNEL_UPLOAD_RE);
			$in_line = '' if $in_line =~ /\r|\n/;
			if ($do_upload)
			{
				if (-f $kernel_filename)
				{
					$kernel_file_changed = 0;
					buddy_Binary::uploadBinary($port,$kernel_filename);
				}
				else
				{
					print "WARNING - $kernel_filename not found. Not uploading!\n";
				}
			}
		}
		$in_line = '';
	}
}


#==============================================================================
# THE MAIN LOOP
#==============================================================================

my $CTRL_A_TIMEOUT = 4;
my $last_ctrl_a = 0;
my $system_check_time = 0;


while (1)
{
	# transmit pending $file_server_request

	if ($port && $file_server_request)
	{
		if ($file_server_request =~ /BASE64/)
		{
			display($dbg_fileserver,0,"main loop sending file_server_request (BASE64) len=".length($file_server_request));
		}
		else
		{
			display($dbg_fileserver,0,"main loop sending file_server_request($file_server_request)");
		}

		# if it's been more than 5 seconds since we last wrote it,
		# write the magic ctrl-A to turn on file_server_mode in teensyPiLooper
		# and wait 1 second ...

		if ($rpi)
		{
			my $now = time();
			if ($now > $last_ctrl_a + $CTRL_A_TIMEOUT)
			{
				display($dbg_fileserver+1,0,"main loop sending ctrlA");
				$port->write(chr(1));
				sleep(0.3);
			}
		}

		# write the request

		$port->write($file_server_request."\r\n");
		$file_server_request = '';

		$last_ctrl_a = time();
	}

    #--------------------------
    # receive and display
    #--------------------------

	readProcessPort();

    #---------------------------------------
    # check for any keyboard events
    #---------------------------------------
    # highest priority is ctrl-C

    if ($in->GetEvents())
    {
        my @event = $in->Input();
        # print "got event '@event'\n" if @event;
        if (@event && isEventCtrlC(@event))			# CTRL-C
        {
            print "exiting buddy!\n";
            if ($port)
            {
                $port->close();
                $port = undef;
            }
			# $sock is closed automatically as needed
            exit(0);
        }

        my $char = getChar(@event);

		if (defined($char))
		{

			if ($con && ord($char) == 4)            				# CTRL-D
			{
				$con->Cls();    # manually clear the screen
			}
			elsif ($con && $file_server && ord($char) == 5)         # CTRL-E
			{
				# pop up the fileClient

				my $port = $DEFAULT_PORT + $COM_PORT;

				# print "PACKAGED=".Cava::Packager::IsPackaged()."\n";	# 0 or 1
				# print "BIN_PATH=".Cava::Packager::GetBinPath()."\n";	# executable directory
				# print "EXE_PATH=".Cava::Packager::GetExePath()."\n";	# full executable pathname
				# print "EXE=".Cava::Packager::GetExecutable()."\n";		# leaf executable filename

				my $command = Cava::Packager::IsPackaged() ?
					Cava::Packager::GetBinPath()."/fileClient.exe $port" :
					"perl /base/Pub/FS/fileClient.pm $port";

				my $pid = system 1, $command;
				display($dbg_fileserver,0,"fileClient pid="._def($pid));
			}


			# A binary upoad can be triggered if the circl rPI *happens*
			# to be in the few seconds after booting where it is showing
			# the signature.  This is an emergency backup method?!?

			elsif ($rpi && ord($char) == 24)     		# CTRL-X
			{
				uploadBinary($port||$sock,$kernel_filename);
			}

			# send console-in chars to $port or $sock

			elsif ($port || $sock)
			{
				my $out = $port || $sock;
				# Note that we are writing out a zeroes to $sock
				# in systemCheck() to trigger socket lost error handling

				$out->write($char);
				if (ord($char) == 13)
				{
					if ($crlf)
					{
						$out->write(chr(10)) ;
						print "\r\n";;
					}
				}
				elsif ($crlf)
				{
					if (ord($char)==8)
					{
						print $char;
						print " ";
						print $char;
					}
					elsif (ord($char) >= 32)
					{
						print $char;
					}
				}
			}
		}
    }

    #---------------------
    # arduino check
    #---------------------
    # take com port offline if in_arduino

    if ($in_arduino_build && $port)
    {
        print("COM$COM_PORT closed for Arduino Build\n");
        $port->close();
        $port = undef;
        showStatus();
    }


    #---------------------
    # system check
    #---------------------
    # check immediately for opened port
    # but only every so often for closed / kernel changes ...

	if ($sock_ip)
	{
		connectSocket() if (!$sock)
	}
    elsif (!$port && !$in_arduino_build)
    {
	    # print("opening COM$COM_PORT after Arduino Build\n");
        $port = initComPort();
		if ($port)
		{
			# print("COM$COM_PORT opened after Arduino Build\n");
			showStatus();
		}
    }

    if (time() > $system_check_time + $SYSTEM_CHECK_TIME)
    {
        $system_check_time = time();
        systemCheck();
    }

	# finished - miscellaneous

	sleep(0.01);		# keep machine from overheating

}   # while (1) main loop



1;
