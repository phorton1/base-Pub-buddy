#!/usr/bin/perl
#------------------------------------------------------------
# winTab
#------------------------------------------------------------
# This is the main window in the program. A tab in the frame.
#
# It creates, manage, and maps to an instance of a BuddyBox
# Window running as a separate process on the same machine.
#
# For the moment it will just instantiate the DosBox and be blank

package Pub::Buddy::winTab;
use strict;
use warnings;
use Wx qw(:everything);
use Wx::Event qw(
	EVT_SIZE
	EVT_IDLE );
use Pub::Utils;
use Pub::WX::Window;
use Pub::Buddy::buddyClient;
#use Pub::FS::SessionClient;
#use Pub::FS::fileClientResources;
#use Pub::FS::fileClientPane;
#use Pub::FS::fileClientHostDialog;
use base qw(Wx::Window Pub::WX::Window);


our $dbg_tab = 0;

my $PAGE_TOP = 40;
my $SPLITTER_WIDTH = 10;

my $instance = 0;


#---------------------------
# new
#---------------------------

sub new
	# the 'data' member is the name of the connection information
{
	my ($class,$frame,$id,$book,$data) = @_;

	if (!$data)
	{
		error("No data specified");
		return;
	}

	$instance++;

	display($dbg_tab,0,"new fileClientWindow() instance=$instance");
	display_hash($dbg_tab,0,"data",$data);
	my $this = $class->SUPER::new($book,$id);
	$this->MyWindow($frame,$book,$id,$data->{session_name},$instance);
    $this->{name} = $data->{session_name};    # should already be done

	if (1)
	{
		$this->{client} = Pub::Buddy::buddyClient->new($data->{remote_port});
		if (!$this->{client})
		{
			error("Could not create client session!");
			return;
		}
		display($dbg_tab,-1,"client started");
		$this->{client}->sendPacket("HELLO");
	}



	# Instantiate the Buddy Box with the given port

	# my $port = $DEFAULT_PORT + $instance;
    #
	# # print "PACKAGED=".Cava::Packager::IsPackaged()."\n";	# 0 or 1
	# # print "BIN_PATH=".Cava::Packager::GetBinPath()."\n";	# executable directory
	# # print "EXE_PATH=".Cava::Packager::GetExePath()."\n";	# full executable pathname
	# # print "EXE=".Cava::Packager::GetExecutable()."\n";		# leaf executable filename
    #
	# my $command = Cava::Packager::IsPackaged() ?
	# 	Cava::Packager::GetBinPath()."/BuddyBox.exe $port" :
	# 	"perl /base/Pub/Buddy/BuddyBox.pm $port";
    #
	# my $pid = system 1, $command;
	# display($dbg_tab,0,"BuddyApp pid="._def($pid));


	# my $port = $ARGV[0] || $DEFAULT_PORT;
	# display($dbg_tab,0,"creating session on port($port)");
    # $this->{session} = Pub::FS::SessionClient->new({ PORT => $port});
    # if (!$this->{session})
    # {
    #     error("Could not create client session!");
    #     return;
    # }

    # Create controls, windows, etc

    # $this->{follow_dirs} = Wx::CheckBox->new($this,-1,'follow dirs',[10,10],[-1,-1]);
    # $this->{splitter} = Wx::SplitterWindow->new($this, -1, [0, $PAGE_TOP]); # ,[400,400], wxSP_3D);
    # $this->{pane1}    = Pub::Buddy::winFilePane->new($this,$this->{splitter},$this->{session},1,$this->{local_dir});
    # $this->{pane2}    = Pub::Buddy::winFilePane->new($this,$this->{splitter},$this->{session},0,$this->{remote_dir});
    #
    # $this->{splitter}->SplitVertically(
    #     $this->{pane1},
    #     $this->{pane2},460);

    $this->doLayout();

    # Populate

    # $this->{pane1}->populate();
    # $this->{pane2}->populate();

    # Finished

	EVT_IDLE($this,\&onIdle);
    EVT_SIZE($this,\&onSize);
	return $this;
}



sub onClose
{
	my ($this,$event) = @_;
	display(3,1,"winTab::onClose() called");
    # $this->{session}->disconnect()
    #     if ($this->{session} &&
    #         $this->{session}->isConnected());
    # $this->{session} = undef;
	$this->SUPER::onClose();
	$event->Skip();
}



sub doLayout
{
	my ($this) = @_;
	my $sz = $this->GetSize();
    my $width = $sz->GetWidth();
    my $height = $sz->GetHeight();
    # $this->{splitter}->SetSize([$width,$height-$PAGE_TOP]);
}



sub onSize
{
    my ($this,$event) = @_;
	$this->doLayout();
    $event->Skip();
}


sub onIdle
{
    my ($this,$event) = @_;
	# display($dbg_tab,0,"onIdle()");
	my $packet = $this->{client} ? $this->{client}->getPacket() : '';
	if ($packet)
	{
		display($dbg_tab+1,-1,"got packet $packet");
	}
	# if the socket has gone away, we should close the tab.
	# if it's the 1st instance, we should close the app.

	# sleep(0.1);
	$event->RequestMore(1);
}



1;
