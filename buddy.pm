#--------------------------------------------------------
# buddy - a Telnet CONSOLE for use with my applications
#--------------------------------------------------------
#
#   -auto  	finds the 'best' COM port or SOCK_IP to use
#           with my existing applicatons like theClock3,
#           teensyExpression, or myIOT devices.
#
#   -auto_no_remote
#			same as -auto but does not do an SSDP scan
#           for guys who want to actually use buddy with
#           any old local port
#
#   COM port number or IP addresss
#
#      If an IP address is provided, it may optionally include a port
#             192.168.0.123:80
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
#          but sometimes it's useful to see what's being typed.
#
#   -arduino   watches for arduino builds (given by a known process name)
#              and disconnects the comm port while the build is active,
#              and reconnects 2 seconds after it finishes. Also causes
#              the same to happen on the presences of a semaphore file
#              given by $ARDUINO_SEMAPHORE_FILE, which can be overriden
#              with an environment variable. The semaphore filen is
#              currently created and removed my upload_spiffs.pm script
#              called from Komodo
#
#   -rpi       watches for kernel changes and uploads new kernels to the rPi automatically
#              allows for ^X to upload the kernel manually. Also turns on magic CTRL-A
#			   for teensyPiLooper for -file_server.
#
#   -file_server   for use currently only with teensyExpression, starts a
#          SerialBridge which can be hit with my fileClient over a
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
#	-file_client  implies -file_server
#			Will start the file_client automatically if a valid connection
#           is made at startup (but not otherwise)
#
#--------------------------------------------------------------------------
# keyboard UI
#--------------------------------------------------------------------------
#
#	ctrl-C  exits buddy
#   ctrl-D  clear the scrreen
#   ctrl-E  pops up the file client if appropriate
#   ctrl-X  starts an rPI upload cycle if appropriate
#
#   Note that ctrl-B reboots the rPi if using teensyPi or teensyPiLooper
#   and that ctrl-A is a magic message to them if -rpi
#
#--------------------------------------------------------------------------
# Generalized rPi auto-upload scheme for use with my Circle bootloader
#--------------------------------------------------------------------------
# A scheme for auto-uploading binary images to the rPi in conjunction
# with teensyPi.ino or teensyPiLooper.ino when -rpi is specified.
#
# There is a "registry file" given by $REGISTRY_FILENAME that contains the
# name of a kernel.img, given by $kernel_filename. Buddy watches for changes
# to either. When the timestamp of the $kernel_filename changes, an auto-upload
# is triggered.
#
# A change to the registry file reloads the $kernel_filename, but
# does not initiate an upload.  A change of the $kernel_filename,
# likewise just gets its timestamp but does not trigger an upload.
# It is only when the kernel_filename has not changed, but it's
# date time stamp has changed, that an upload is triggered.
#
# Buddy uploads a new kernel by sending CTRL-B to teensyPi/Looper which
# cause it to reboot the rPi as it sets a state variable $kernel_file_changed
# when then causes buddy to look for a line containing the
# $KERNEL_UPLOAD_RE pattern, at which point it starts uploading
# the binary image.
#
# The upload can also be triggered manually by pressing ctrl-X.
#
#------------------------------------------------------------------------
# ENIRONMENT VARIABLES
#------------------------------------------------------------------------
# The various paths an filenames, even in the release executable,
# are set to my own personal machine's configuration.  For any
# who might actually want to use this feature, several things
# can be persistently changed with environment variables.
#
# BUDDY_ARDUINO_RE		$ARDUINO_PROCESS_RE	DEFAULT "arduino-builder.exe"
# BUDDY_ARDUINO_SEM		$ARDUINO_SEMAPHORE_FILE DEFAULT "/junk/in_upload_spiffs.txt";
# BUDDY_KERNEL_REG		$REGISTRY_FILENAME		DEFAULT "/base_data/console_autobuild_kernel.txt";


#-------------------------------------------------------------------
# interaction with my personal KOMODO keystroke macros
#-------------------------------------------------------------------
# Per se this has nothing to do with Buddy, but is documented here
# for my own purposes
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
#       /base_data/console_autobuild_kernel.txt pointing
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

package apps::buddy::buddy;
use strict;
use warnings;
use threads;
use threads::shared;
use Cava::Packager;
use Socket;
use Time::HiRes qw( sleep usleep  );
use Win32::Console;
use Win32::Process::List;
use Win32::SerialPort qw(:STAT);
use IO::Socket::INET;
# use Net::Telnet;
use Pub::Utils;
use Pub::ComPorts;
use Pub::SSDPScan;
use Pub::FS::SerialBridge;
use Pub::FS::SerialSession;
use apps::buddy::buddyColors;
use apps::buddy::buddyBinary;
use apps::buddy::buddyGrab;
use sigtrap 'handler', \&onSignal, qw(normal-signals);

Pub::Utils::initUtils();


$debug_level = -5 if Cava::Packager::IsPackaged();
	# set release debug level
createSTDOUTSemaphore("buddySTDOUT");


$| = 1;     # IMPORTANT - TURN PERL BUFFERING OFF MAGIC


my $dbg_buddy = 0;
	# 0 = program basics
	# -1 = program details
my $dbg_process = 1;
	# 0 = the process stuff in arduino_thread
	# -1 = show the process list


my $DEFAULT_SOCK_PORT = 23;
	# Default TCP/IP port is TELNET.
	# Somewhere I have a server on port 80
my $DEFAULT_BAUD_RATE = 115200;


my $SYSTEM_CHECK_TIME = 3;
    # check for changed COM/SOCKET connections and, for rpi,
	# new kernel.img every this many seconds
my $KERNEL_UPLOAD_RE = 'Press <space> within \d+ seconds to upload file';


# Psuedo-constants that can be overriden by ENV vars

my $ARDUINO_PROCESS_RE = 	 $ENV{BUDDY_ARDUINO_RE}  	|| 'arduino-builder\.exe|esptool\.exe';
my $ARDUINO_SEMAPHORE_FILE = $ENV{BUDDY_ARDUINO_SEM} 	|| '/junk/in_upload_spiffs.txt';
my $REGISTRY_FILENAME = 	 $ENV{BUDDY_KERNEL_REG} 	|| '/base_data/console_autobuild_kernel.txt';

#


#---------------------------
# setup diretories
#---------------------------
# If buddy has prefs, they will be more 'standard' Pub::Prefs
# than fileClient, and will be assumed to be editable by hand
# only, holding no program state.

if (0)
{
	setStandardTempDir("buddy");
	# print "temp_dir=$temp_dir\n";
}

if (0)
{
	setStandardDataDir("buddy");
	# print "data_dir=$data_dir\n";
	# open OUT,">$data_dir/junk.txt";
	# print OUT "wha ha ha\n";
	# close OUT;
}

setStandardCavaResourceDir('/base/Pub/buddy/_resources');
# print "resource_dir=$resource_dir\n";



#-----------------------
# command line params
#-----------------------

my $AUTO:shared = 0;
my $AUTO_NO_REMOTE:shared = 0;
my $COM_PORT:shared = 0;
my $SOCK_IP:shared = '';
my $SOCK_PORT:shared = 0;
my $BAUD_RATE:shared = $DEFAULT_BAUD_RATE;
my $CRLF:shared = 0;
my $RPI:shared = 0;
my $ARDUINO:shared = 0;
my $START_FILE_SERVER:shared = 0;
my $START_FILE_CLIENT:shared = 0;



#-----------------------
# working variables
#-----------------------

# my $CONSOLE = Win32::Console->new(STD_OUTPUT_HANDLE);
# now from Pub::Utils

my $CONSOLE_IN = Win32::Console->new(STD_INPUT_HANDLE);
$CONSOLE_IN->Mode(ENABLE_MOUSE_INPUT | ENABLE_WINDOW_INPUT );
$CONSOLE->Attr($COLOR_CONSOLE);
$CONSOLE->SetIcon("$resource_dir/buddy.ico");

my $com_port;
my $com_sock;;
my $file_server;

my $registry_filetime = getFileTime($REGISTRY_FILENAME);
my $kernel_check_time = 0;
my $kernel_filename = '';
my $kernel_filetime = 0;
my $kernel_file_changed = 0;

my $in_arduino_build:shared = 0;
my $connect_fail_reported = 0;
	# only report initial fail


#--------------------------------------------
# output routines and signal handler
#--------------------------------------------

sub onSignal
{
    my ($sig) = @_;
	buddyWarning("terminating on SIG$sig");
	exitBuddy();
}

sub buddyError
{
	my ($msg) = @_;
	$CONSOLE->Attr($color_red);
	print "buddy Error: $msg\n";
	$CONSOLE->Attr($COLOR_CONSOLE);
}

sub buddyWarning
{
	my ($msg) = @_;
	$CONSOLE->Attr($color_yellow);
	print "buddy Warning: $msg\n";
	$CONSOLE->Attr($COLOR_CONSOLE);
}

sub buddyMsg
{
	my ($msg) = @_;
	$CONSOLE->Attr($COLOR_CONSOLE);
	print "buddy: $msg\n";
}

sub quit
{
	my ($msg,$quiet) = @_;
	buddyError($msg) if $msg;
	if (!$quiet)
	{
		print "Hit any key to close window -->";
		# getc();

		my $done = 0;
		while (!$done)
		{
			if ($CONSOLE_IN->GetEvents())
			{
				my @event = $CONSOLE_IN->Input();
				$done = getChar(@event);
			}
		}
	}
	$CONSOLE->Title("buddy finished");
	kill 6,$$;
	# exit(0);
}

sub exitBuddy
{
	my ($quiet) = @_;
	$quiet ||= 0;
	buddyWarning("exiting($quiet)!");
	if ($com_port)
	{
		$com_port->close();
		$com_port = undef;
	}
	$file_server->stop() if $file_server;
	quit('',$quiet);
}

sub buddyNotify
{
	my ($enable,$msg) = @_;
	Pub::FS::SerialSession::setComPortConnected($enable);
	buddyMsg($msg);
	my $send_msg = ($enable ? $PROTOCOL_ENABLE: $PROTOCOL_DISABLE).$msg;
	notifyAll($send_msg) if $file_server;
}


#-------------------------------------------
# processCommandLine()
#-------------------------------------------

sub processCommandLine
{
	my (@args) = @_;
	display($dbg_buddy+1,-1,"processCommandLine(".scalar(@args).")");

	my $arg_num = 0;
	while ($arg_num < @args)
	{
		my $arg = $args[$arg_num++];

		if ($arg =~ /^-(.*)/)
		{
			my $val = $1;
			if ($val eq 'auto')
			{
				$AUTO = 1;
			}
			elsif ($val eq 'auto_no_remote')
			{
				$AUTO = 1;
				$AUTO_NO_REMOTE = 1;
			}
			elsif ($val eq 'rpi')
			{
				$RPI = 1;
			}
			elsif ($val eq 'crlf')
			{
				$CRLF = 1;
			}
			elsif ($val eq 'arduino')
			{
				$ARDUINO = 1;
			}
			elsif ($val eq 'file_server')
			{
				$START_FILE_SERVER = 1;
			}
			elsif ($val eq 'file_client')
			{
				$START_FILE_CLIENT = 1;
				$START_FILE_SERVER = 1;
			}
			else
			{
				quit("Illegal command line argument: -$arg");
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
			($SOCK_IP,$SOCK_PORT) = ($1,$3);
			$SOCK_PORT ||= $DEFAULT_SOCK_PORT;
			# default to echo/crlf
			$CRLF = 1;
		}
		else
		{
			quit("Illegal command line argument: $arg");
		}
	}

	display($dbg_buddy+1,-1,"    -auto") if $AUTO;
	display($dbg_buddy+1,-1,"    COM_PORT = $COM_PORT") if $COM_PORT;
	display($dbg_buddy+1,-1,"    SOCK_IP = $SOCK_IP:$SOCK_PORT") if $SOCK_IP;
	display($dbg_buddy+1,-1,"    -rpi") if ($RPI);
	display($dbg_buddy+1,-1,"    -crlf") if ($CRLF);
	display($dbg_buddy+1,-1,"    -arduino") if $ARDUINO;
	display($dbg_buddy+1,-1,"    -file_server") if $START_FILE_SERVER;

	quit("A COM port, IP address, or AUTO must be specified")
		if !$COM_PORT && !$SOCK_IP && !$AUTO;
	quit("Only one of COM port, IP address, or AUTO may be specified")
		if ($COM_PORT?1:0) + ($SOCK_IP?1:0) + $AUTO > 1;
}



#-------------------------------------------
# checkAuto()
#-------------------------------------------

my $dbg_auto = 0;
my $SSDP_TIMEOUT = 15;
my $ssdp_found:shared = '';


sub onSSDPDevice
{
    my ($rec) = @_;
	my $iot_device = $rec->{SERVER} =~ /myIOTDevice UPNP\/1.1 (.*)\// ? $1 :
		$rec->{SERVER} ? $rec->{SERVER} :
		$rec->{ST} ? $rec->{ST} :
		"unknown device";
	$ssdp_found = shared_clone([$rec->{ip}, $iot_device]);
}


sub checkAuto
{
	my $ssdp_started = $AUTO_NO_REMOTE ? 0 :
		Pub::SSDPScan::start($SEARCH_MYIOT,\&onSSDPDevice,28);
	my $ports = Pub::ComPorts::find();
	my $ssdp_time = time();

	my $done = 0;
	my $found_any = '';
	my $found_TE = '';
	my $found_arduino = '';

	if ($ports)
	{
		for my $port (keys %$ports)
		{
			my $rec = $ports->{$port};
			$found_any ||= $rec;
			$found_TE ||= $rec if $rec->{midi_name} eq "teensyExpressionv2";
			$found_arduino ||= $rec if $rec->{device};
		}
	}

	if ($found_TE)
	{
		buddyMsg("found TeensyExpression on COM$found_TE->{num}");
		$ARDUINO = 1;
		$START_FILE_SERVER = 1;
		$COM_PORT = $found_TE->{num};
		$done = 1;
	}
	elsif ($found_arduino)
	{
		buddyMsg("found a $found_arduino->{device} on COM$found_arduino->{num}");
		$ARDUINO = 1;
		$CRLF = 1 if $found_arduino->{device} =~ /ESP32/i;
		$COM_PORT = $found_arduino->{num};
		$done = 1;
	}

	# gives precedence to any known devices identified by ComPorts
	# over any SSDP (myIOT) devices .... but, then takes any myIOT
	# devices before any old random com port ...

	if ($ssdp_started && !$done)
	{
		my $now = time();
		while (!$ssdp_found && $now < $ssdp_time + $SSDP_TIMEOUT)
		{
			my $secs = $SSDP_TIMEOUT - ($now - $ssdp_time);
			buddyMsg("Searching for remote devices($secs/15) ...");
			sleep(2);
			$now = time()
		}
		if ($ssdp_found)
		{
			buddyMsg("found REMOTE $ssdp_found->[1] at $ssdp_found->[0]");
			$SOCK_IP = $ssdp_found->[0];
			$SOCK_PORT = $DEFAULT_SOCK_PORT;
			$CRLF = 1;
			$done = 1;
		}
	}

	# take any old com port that is found

	if (!$done && $found_any)
	{
		buddyMsg("found COM$found_any->{num} VID($found_any->{VID}) PID($found_any->{PID})");
		$COM_PORT = $found_any->{num};
		$done = 1;
	}

	# currently only device for fileServer is teensyExpression

	if (!$found_TE)
	{
		$START_FILE_SERVER = 0;
		$START_FILE_CLIENT = 0;
	}
	Pub::SSDPScan::stop() if $ssdp_started;

	quit("Could not find any devices to automatically connect to!") if !$done;
}




#------------------------------------------------
# methods
#------------------------------------------------


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
        display($dbg_buddy+1,-1,"ctrl-C pressed ...");
        return 1;
    }
    return 0;
}

sub showStatus
{
	my $title = "Buddy ";
	$title .= $SOCK_IP ? "$SOCK_IP:$SOCK_PORT" : "COM$COM_PORT ";
	$title .= " CONNECTED" if $com_port || $com_sock;
	$title .= " -crlf" if $CRLF;
	$title .= " -arduino" if $ARDUINO;
	$title .= " IN_BUILD" if $in_arduino_build;
	$title .= " -file_server $ACTUAL_SERVER_PORT"
		if $ACTUAL_SERVER_PORT && $START_FILE_SERVER;
	$title .= " -rpi $kernel_filename" if $RPI;
	$CONSOLE->Title($title);
}


sub connectSocket
{
	display($dbg_buddy,-1,"Connecting TCP/IP to $SOCK_IP:$SOCK_PORT");
	my @psock = (
		PeerAddr => $SOCK_IP,
		PeerPort => $SOCK_PORT, # "udp(80)",         #  "http(80)",
		Proto    => 'tcp',      # 'udp'
		Timeout  => 5,          # timeout for connection
		Blocking => 0,
		# KeepAlive  => 1,
	);
	$com_sock = IO::Socket::INET->new(@psock);
	if (!$com_sock)
	{
		buddyNotify(0,"could not connect to %sock_ip:$SOCK_PORT")
			if !$connect_fail_reported;
	}
	else
	{
		# setsockopt($com_sock, SOL_SOCKET, SO_KEEPALIVE, 1);

		buddyNotify(1,"Connected to $SOCK_IP:$SOCK_PORT");
		binmode $com_sock;
		$com_sock->blocking(0);

	}
	$connect_fail_reported = 1;
	showStatus();
}


sub initComPort
{
    # print "initComPort($COM_PORT,$BAUD_RATE)\n";
    $com_port = Win32::SerialPort->new("COM$COM_PORT",1);

    if ($com_port)
    {
		buddyNotify(1,"COM$COM_PORT opened");

        # This code modifes Win32::SerialPort to allow higher baudrates

        $com_port->{'_L_BAUD'}{78440} = 78440;
        $com_port->{'_L_BAUD'}{230400} = 230400;
        $com_port->{'_L_BAUD'}{460800} = 460800;
        $com_port->{'_L_BAUD'}{921600} = 921600;
        $com_port->{'_L_BAUD'}{1843200} = 1843200;

        $com_port->baudrate($BAUD_RATE);
        $com_port->databits(8);
        $com_port->parity("none");
        $com_port->stopbits(1);

        # $com_port->buffers(8192, 8192);
        $com_port->buffers(60000,8192);

        $com_port->read_interval(100);    # max time between read char (milliseconds)
        $com_port->read_char_time(5);     # avg time between read char
        $com_port->read_const_time(100);  # total = (avg * bytes) + const
        $com_port->write_char_time(5);
        $com_port->write_const_time(100);

        $com_port->handshake("none");   # "none", "rts", "xoff", "dtr".
			# handshaking needed to be turned off for uploading binary files
            # or else sending 0's, for instance, would freeze

		# $com_port->dtr_active(1);
        # $com_port->binary(1);

        if (!$com_port->write_settings())
        {
            quit("Could not configure COM$COM_PORT");
        }

		$com_port->binary(1);
		showStatus();
    }
	else
	{
		buddyNotify(0,"could not connect to COM$COM_PORT")
			if !$connect_fail_reported;
	}
	$connect_fail_reported = 1;
    return $com_port;
}


sub startFileClient
{
	# print "PACKAGED=".Cava::Packager::IsPackaged()."\n";	# 0 or 1
	# print "BIN_PATH=".Cava::Packager::GetBinPath()."\n";	# executable directory
	# print "EXE_PATH=".Cava::Packager::GetExePath()."\n";	# full executable pathname
	# print "EXE=".Cava::Packager::GetExecutable()."\n";		# leaf executable filename

	buddyMsg("Starting fileClient on port($ACTUAL_SERVER_PORT)");
	my $params = "-buddy $ACTUAL_SERVER_PORT";
	my $command = Cava::Packager::IsPackaged() ?
		Cava::Packager::GetBinPath()."/fileClient.exe $params" :
		"perl /base/apps/fileClient/fileClient.pm $params";
		# add 'start' to the previous line to put the fileClient in it's
		# own dos box, but note that you will not be able to see it exit.

	my $pid = system 1, $command;
	display($dbg_buddy+1,-1,"INVOKE FILE CLIENT WITH PID($pid)");
	buddyError("Could not start fileClient")
		if !$pid;

}


#-------------------------------------------
# arduino_thread()
#-------------------------------------------

sub arduino_thread
	# watch for a process indicating an Arduino build is happening
	# and set $in_arduino_build if it is, or clear it if not
{
    while (1)
    {
		my $found = -f $ARDUINO_SEMAPHORE_FILE;
		if (!$found)
		{
			my $pl = Win32::Process::List->new();
			my %processes = $pl->GetProcesses();

			display($dbg_process,0,"PROCESS_LIST");
			foreach my $pid (sort {$processes{$a} cmp $processes{$b}} keys %processes )
			{
				my $name = $processes{$pid};
				display($dbg_process+1,0,"pid($pid) = $name") if $name;
				if ($name =~ $ARDUINO_PROCESS_RE)
				{
					display($dbg_process,0,"Found process $ARDUINO_PROCESS_RE");
					$found = 1;
					last;
				}
			}
		}

		if ($found && !$in_arduino_build)
		{
			$in_arduino_build = 1;
		}
		elsif ($in_arduino_build && !$found)
		{
			sleep(2);
			$in_arduino_build = 0;
			display($dbg_buddy+1,-1,"resuming after sleep");
		}

        sleep(1);
    }
}


#-------------------------------------------
# systemCheck()
#-------------------------------------------

sub systemCheck
	# every $SYSTEM_CHECK_TIME (3) seconds
{
    # print "system check ...\n";
    # check for dropped $com_port

    if ($com_port)
    {
        my ($BlockingFlags, $InBytes, $OutBytes, $LatchErrorFlags) = $com_port->status();
        if (!defined($BlockingFlags))
        {
            # $save_port = $com_port;
            # save the port to prevent reporting of errors
            # when Win32::SerialPort tries to close it when
            # we set it to undef below.  So far, no negative
            # side effects from this ...

            buddyNotify(0,"COM$COM_PORT disconnected");
            $com_port = undef;
            showStatus();
        }
    }

	# send a null character for keep alive

	elsif ($com_sock)
	{
		$com_sock->write(chr(0));

	}

    # check for changes to the kernel_filename or kernel_filetime

	if ($RPI)
	{
		if (!open(IFILE,"<$REGISTRY_FILENAME"))
		{
			error("could not open registry_file $REGISTRY_FILENAME for reading!");
			$RPI = 0;
		}
		else
		{
			my $filename = <IFILE>;
			$filename =~ s/\s+$//g;
			$filename =~ s/\\/\//g;
			close IFILE;

			if ($kernel_filename ne $filename)
			{
				$kernel_filename = $filename;
				buddyMsg("setting kernel_filename to $kernel_filename");
				$kernel_filetime = getFileTime($kernel_filename);
				warning($dbg_buddy,0,"could not getFileTime($kernel_filename)")
					if !$kernel_filetime;
			}
		}

		if ($kernel_filename)
		{
			my $filetime = getFileTime($kernel_filename);
			if ($kernel_filetime ne $filetime)
			{
				$kernel_filetime = $filetime;
				buddyMsg("$kernel_filename file_time changed");

				if ($kernel_filetime)
				{
					if ($com_port)
					{
						$kernel_file_changed = 1;
						buddyWarning("AUTO-REBOOTING rpi (sending ctrl-B)");
						$com_port->write("\x02");		# CTRL-B
					}
					else
					{
						buddyError("Cannot reboot rpi - COM$COM_PORT is not open!");
					}

				}	# filetime exists
			}	# filetime changed
		}	# kernel_filename
	}	# rpi


}   # systemCheck()


#-------------------------------------------
# readProcessPort()
#-------------------------------------------

my $is_esc_line = 0;
my $esc_cmd = '';
my $esc_color = $COLOR_CONSOLE;
my $esc_cls = 0;

my $in_line = '';


sub readProcessPort
{
	my $buf;
	my $bytes;

	if ($com_port)
	{
		my ($BlockingFlags, $InBytes, $OutBytes, $LatchErrorFlags) = $com_port->status();
			# display($dbg_buddy,-1,">$BlockingFlags, $InBytes, $OutBytes, $LatchErrorFlags");
			# we differentiate fileSystem replies from regular output
			# teensyEpression output by assuming that regular output always
			# starts with an ESC color sequence.
		($bytes,$buf) = $com_port->read($InBytes) if $InBytes;
	}
	elsif ($com_sock)
	{
		$bytes = sysread($com_sock,$buf,1024);
			# Note that we are writing out a zero in systemCheck() to trigger
			# this error handler.

		if ($! && $! !~ /A non-blocking socket operation could not be completed immediately/)
		{
			display($dbg_buddy+1,-1,"ERROR: $!");
			buddyNotify("Lost Connection to $SOCK_IP:$SOCK_PORT");
			$com_sock->close();
			$com_sock = undef;
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
	# I used to support character by character output for
	# 'esc lines' to support things like myIOT::connect(),
	# but it looks like that is no longer necessary, so
	# henceforth I am buffering 'esc lines' and their
	# 'esc commands' so that they work better with
	# display from child process (fileClient) and threads
	# (FS:SerialBridge and SerialSession)
	#
	# Although the below code is cleaner, and acts a little
	# nicer if you don't care about char-by-char output,
	# it still does not work in a multi-process environment,
	# though it somewhat appears to work within threads in
	# this process.


	my $do_upload = 0;
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
				$esc_color = colorAttr($color);
				$esc_cmd = '';
			}
			if ($esc_cmd =~ /\x1b\[(\d+);(\d+)m/)
			{
				my ($fg,$bg) = ($1,$2);
				$bg -= 10;
				# print "setting color($fg,$bg)\n";
				$esc_color = colorAttr($bg)<<4 | colorAttr($fg);
				$esc_cmd = '';
			}
			elsif ($esc_cmd =~ /\x1b\[[23]J/)
			{
				$esc_cls = 1;
				$esc_cmd = '';
			}
			elsif (length($esc_cmd) > 9)
			{
				$esc_cmd = '';
			}
		}

		# escape commands cannot be sent in the middle of line

		elsif (ord($c) == 27)	# (!$in_line && ord($c) == 27)
		{
			# print("starting escape command\n");
			$esc_cmd = $c;
			if (!$is_esc_line)
			{
				$esc_color = $COLOR_CONSOLE;
				$esc_cls = 0;
			}
			$is_esc_line = 1;
		}

		elsif (ord($c) == 10)		# \n == 10 == end of line
		{
			# display(0,0,"inline=$in_line");

			$in_line =~ s/\s+$//g;

			if ($in_line =~ /SCREEN_GRAB\((\d+)x(\d+)\)/)
			{
				($grab_width, $grab_height) = ($1,$2);
				$in_screen_grab = $grab_width * $grab_height * 3;
				warning($dbg_buddy,-1,"doing SCREEN_GRAB($grab_width X $grab_height) $in_screen_grab bytes");
				$screen_grab = '';
			}
			elsif ($in_line =~ s/^file_reply\((\d+)\)://)
			{
				my $req_num = $1;
				if ($dbg_request <= 0)
				{
					my $show_request = $in_line;
					$show_request =~ s/\s$//g;
					if ($show_request =~ s/(.*$PROTOCOL_BASE64\t.*\t.*\t)//)
					{
						my $hdr = $1;
						display($dbg_request,0,"main loop got file_reply($req_num,$hdr)\t".length($show_request)." encoded bytes)");
					}
					else
					{
						$show_request =~ s/\r/\r\n/g;
						display($dbg_request,0,"main loop got file_reply($req_num)\r$show_request");
					}
				}
				while ($serial_file_reply{$req_num})
				{
					warning($dbg_request+2,-1,"waiting for !serial_file_reply($req_num)");
					sleep(0.01);
				}
				$serial_file_reply{$req_num} .= $in_line;	# ."\n";	# why the terminal \n??
			}
			else
			{
				my $got_sem = waitSTDOUTSemaphore();
				if ($is_esc_line)
				{
					$CONSOLE->Cls() if $esc_cls;
					$CONSOLE->Attr($esc_color);
					$is_esc_line = 0;
					$esc_cmd = '';
					$esc_cls = 0;
					$esc_color = $COLOR_CONSOLE;
				}
				print $in_line."\n";
				$CONSOLE->Attr($COLOR_CONSOLE);
				releaseSTDOUTSemaphore() if $got_sem;
				$do_upload = $kernel_file_changed && $in_line =~ $KERNEL_UPLOAD_RE;
			}

			$in_line = '';
		}
		else # if (ord($c) != 13)
		{
			$in_line .= $c;
		}
	}	# for each byte

	$CONSOLE->Flush();

	if ($do_upload)
	{
		if (-f $kernel_filename)
		{
			$kernel_file_changed = 0;
			apps::buddy::buddyBinary::uploadBinary($com_port,$kernel_filename);
		}
		else
		{
			warning($dbg_buddy,-1,"WARNING - $kernel_filename not found. Not uploading!");
		}
	}
}


#==================================================================
# MAIN
#==================================================================

display($dbg_buddy,-1,"BUDDY STARTED WITH PID($$)");

processCommandLine(@ARGV);

$CONSOLE->Title("initializing ...");


checkAuto() if $AUTO;

initComPort() if $COM_PORT;
connectSocket() if $SOCK_IP;


if ($ARDUINO)
{
	buddyMsg("Starting arduino_thread");
	my $thread = threads->create(\&arduino_thread);
	$thread->detach();
}


if ($START_FILE_SERVER)
{
	buddyMsg("Starting fileServer");
	sleep(0.2);	# for message to display
	$file_server = Pub::FS::SerialBridge->new();
	quit("could not start fileServer") if !$file_server;

	my $try = 0;
	my $FILE_SERVER_WAIT = 5;
	while ($try++ < $FILE_SERVER_WAIT && !$ACTUAL_SERVER_PORT)
	{
		display($dbg_buddy+1,-1,"waiting($try) for ACTUAL_SERVER_PORT");
		sleep(1);
	}
	quit("could not get fileServer port") if !$ACTUAL_SERVER_PORT;
	buddyMsg("fileServer started on port $ACTUAL_SERVER_PORT");
	showStatus();
}

startFileClient()
	if $START_FILE_CLIENT;	# && ($com_port || $com_sock);


#-----------------------
# THE MAIN LOOP
#-----------------------

my $CTRL_A_TIMEOUT = 4;
my $last_ctrl_a = 0;
my $system_check_time = 0;

display($dbg_buddy,0,"STARTING LOOP");


my $loop_num = 0;

while (1)
{
	# print $loop_num++."\n";
	# transmit pending $serial_file_request

	if ($com_port && $serial_file_request)
	{
		if ($dbg_request < 0)
		{
			my $show_request = $serial_file_request;
			$show_request =~ s/\s$//g;
			if ($show_request =~ s/(.*$PROTOCOL_BASE64\t.*\t.*\t)//)
			{
				my $hdr = $1;
				display($dbg_request,0,"main loop sending serial_file_request($hdr\t".length($show_request)." encoded bytes)");
			}
			else
			{
				$show_request =~ s/\r/\r\n/g;
				display($dbg_request,0,"main loop sending serial_file_request($show_request)");
			}
		}

		# if it's been more than 5 seconds since we last wrote it,
		# write the magic ctrl-A to turn on file_server_mode in teensyPiLooper
		# and wait 1 second ...

		if ($RPI)
		{
			my $now = time();
			if ($now > $last_ctrl_a + $CTRL_A_TIMEOUT)
			{
				display($dbg_request+1,0,"main loop sending ctrlA");
				$com_port->write(chr(1));
				sleep(0.3);
			}
		}

		# write the request

		$com_port->write($serial_file_request);
		$serial_file_request = '';
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

    if ($CONSOLE_IN->GetEvents())
    {
        my @event = $CONSOLE_IN->Input();
        # print "got event '@event'\n" if @event;
        if (@event && isEventCtrlC(@event))				# CTRL-C
        {
			exitBuddy(1);
        }

        my $char = getChar(@event);

		if (defined($char))
		{
			if ($CONSOLE && ord($char) == 4)            # CTRL-D
			{
				$CONSOLE->Cls();    # clear the screen
			}
			elsif ($CONSOLE && ord($char) == 5)         # CTRL-E
			{
				startFileClient();
			}
			elsif ($RPI && ord($char) == 24)     		# CTRL-X
			{
				$kernel_file_changed = 1;
				buddyWarning("AUTO-REBOOTING rpi (sending ctrl-B)");
				$com_port->write("\x02");		# write ctrl-B
			}

			# send console-in chars to $com_port or $com_sock

			elsif ($com_port || $com_sock)
			{
				my $out = $com_port || $com_sock;
					# Note that we are writing out a zeroes to $com_sock
					# in systemCheck() to trigger socket lost error handling

				$out->write($char);
				if (ord($char) == 13)
				{
					if ($CRLF)
					{
						$out->write(chr(10)) ;
						print "\r\n";;
					}
				}
				elsif ($CRLF)
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

    if ($in_arduino_build && $com_port)
    {
		buddyNotify(0,"COM$COM_PORT closed for Arduino Build");
        $com_port->close();
        $com_port = undef;
        showStatus();
    }


    #---------------------
    # system check
    #---------------------
    # check immediately for opened port
    # but only every so often for closed / kernel changes ...

	if ($SOCK_IP)
	{
		connectSocket() if (!$com_sock)
	}
    elsif ($COM_PORT && !$com_port && !$in_arduino_build)
    {
        $com_port = initComPort();
		if ($com_port)
		{
			showStatus();
		}
    }

    if (time() > $system_check_time + $SYSTEM_CHECK_TIME)
    {
        $system_check_time = time();
        systemCheck();
    }

	# finished \

	sleep(0.01);		# keep machine from overheating

}   # while (1) main loop



1;
