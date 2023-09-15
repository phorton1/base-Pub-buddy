#!/usr/bin/perl -w
#-------------------------------------------------------------------
# Pub::Buddy::buddyServerSession
#-------------------------------------------------------------------

package Pub::Buddy::buddyServerSession;
use strict;
use warnings;
use threads;
use threads::shared;
use Time::Hires qw(sleep);
use Pub::Utils;
use Pub::FS::SessionRemote;
use base qw(Pub::FS::SessionRemote);


our $dbg_notify:shared = 1;
our $dbg_server_session = 0;

BEGIN {
    use Exporter qw( import );
	our @EXPORT = (
		qw (
			$dbg_notify
			$dbg_server_session
			pushNotification
		),
	    # forward base class exports
        @Pub::FS::SessionRemote::EXPORT,
	);
};



my @notifications:shared;


sub new
{
    my ($class,$params) = @_;
	$params ||= {};
	$params->{NOBLOCK} = 1;
		# allow for non-blocking get_packet so that we can
		# pushNotifications in onServerLoop()
    my $this = $class->SUPER::new($params);
	return $this;
}

sub pushNotification
{
	my ($packet) = @_;
	display($dbg_notify,-1,"pushNotification($packet)");
	push @notifications,$packet;
}


sub onServerLoop
{
	my ($this,$connect_num) = @_;
	if ($connect_num == 1 &&		# intialial connection
		@notifications)
	{
		my $packet = shift @notifications;
		display($dbg_notify,-1,"sendNotification($packet)");
		$this->send_packet($packet);
	}
	return 1;
}




sub doCommand
{
    my ($this,
		$command,
        $local,
        $param1,
        $param2,
        $param3) = @_;

	display($dbg_server_session+1,-1,"buddyServerSession::doCommand($command)");
	if ($command eq 'CONFIG')
	{
		display($dbg_server_session,-1,"buddyServerSession::doCommand CONFIG($param1)");

		my @args:shared = split(/ /,$param1);
		Pub::Buddy::BuddyBox::processCommandLine(@args);
		return '';
	}
	else
	{
		return $this->SUPER::doCommand($command,$local,$param1,$param2,$param3);
	}
}



1;
