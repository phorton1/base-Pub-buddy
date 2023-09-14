#!/usr/bin/perl -w
#-------------------------------------------------------------------
# Pub::Buddy::buddyServerSession
#-------------------------------------------------------------------
#
# A buddyServerSession is running in the context of a buddyServer.
#
# It generally receives packets from the buddyClientSession which
# can be of a configuration/application nature, or a fileServer
# nature.
#
# It can push notifications to the app that are of a general nature
# (i.e. SSDP from the initial buddyBox, or Connection/Arduino Build
# notifications from the buddyBox.
#
# and forwards them as serial requests to a Serial Server, and
# returns the results from the Serial Server to the to the
# SessionClient.
#
# Anything that is purely local will be handled by the SessionClient
# and will never make its way to this Session.
#
# For purely remote requests, the Session Client will send the socket
# request to this object.  Since we know that
# these requests are NOT actually local requests,

# When the Client makes requests to ITS SessionClient, any requsts
# that are purely local will be handled directly by the base Session
# class, and will never get passed to this Session.
# those that are 'remote', it will, in turn, send the command
# out over the socket, where it will be received by THIS session.
#
# Since the base Session doCommand() method thinks IT is local,
# when we receive a command that








my $SSDP_TIMEOUT = 15;




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

if ($sock_ip)
{
	print "SOCKET: $sock_ip:$sock_port\n";
}
else
{
	print "COM$COM_PORT at $BAUD_RATE baud\n";
}


if ($start_file_server)
#--------------------------------------------------
# checkAuto
#--------------------------------------------------




sub checkAuto
{

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



package Pub::FS::SessionRemote;
use strict;
use warnings;
use threads;
use threads::shared;
use Time::Hires qw(sleep);
use Pub::Utils;
use Pub::FS::FileInfo;
use Pub::FS::Session;
use base qw(Pub::FS::Session);

our $dbg_request:shared = 0;

BEGIN {
    use Exporter qw( import );
	our @EXPORT = (
		qw (
			$dbg_request
			$file_server_request
			$file_server_reply
			$file_reply_pending
		),
	    # forward base class exports
        @Pub::FS::Session::EXPORT,
	);
};


our $file_server_request:shared = '';
our $file_server_reply:shared = '';
our $file_reply_pending:shared = 0;


sub new
{
    my ($class,$params) = @_;
    my $this = $class->SUPER::new($params);
	return $this;
}




#========================================================================================
# Command Processor
#========================================================================================


sub doRemoteRequest
{
	my ($request) = @_;
	if ($request =~ /BASE64/)
	{
		display($dbg_request,0,"doRemoteRequest(BASE64) len=".length($request));
	}
	else
	{
		display($dbg_request,0,"doRemoteRequest($request)");
	}
	$file_server_reply = '';
	$file_server_request = $request;
	$file_reply_pending = 1;

	while ($file_reply_pending)
	{
		display($dbg_request+1,0,"doRemoteRequest() waiting for reply ...");
		sleep(0.2);
	}

	display($dbg_request+1,0,"doRemoteRequest() got reply: '$file_server_reply'");
	display($dbg_request,0,"doRemoteRequest() returning ".length($file_server_reply)." bytes");
}





sub _listRemoteDir
{
    my ($this, $dir) = @_;
    display($dbg_commands,0,"_listRemoteDir($dir)");
	doRemoteRequest("file_command:$SESSION_COMMAND_LIST\t$dir");
	if (!$file_server_reply)
	{
		$this->session_error("_listRemoteDir() - empty reply - returning undef");
		return undef;
	}
    $this->send_packet($file_server_reply);
    display($dbg_commands,0,"_listRemoteDir($dir) returning after send_packet(".length($file_server_reply).")");
	return '';
}

sub _mkRemoteDir
{
    my ($this, $dir, $name) = @_;
    display($dbg_commands,0,"_mkRemoteDir($dir)");
	doRemoteRequest("file_command:$SESSION_COMMAND_MKDIR\t$dir\t$name");
	if (!$file_server_reply)
	{
		$this->session_error("_mkRemoteDir() - empty reply - returning undef");
		return undef;
	}
    $this->send_packet($file_server_reply);
	return '';
}

sub _renameRemote
{
    my ($this, $dir, $name1, $name2) = @_;
    display($dbg_commands,0,"_renameRemote($dir)");
	doRemoteRequest("file_command:$SESSION_COMMAND_RENAME\t$dir\t$name1\t$name2");
	if (!$file_server_reply)
	{
		$this->session_error("_renameRemote() - empty reply - returning undef");
		return undef;
	}
    $this->send_packet($file_server_reply);
	return '';
}




1;
