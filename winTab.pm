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
use Cava::Packager;
use Wx qw(:everything);
use Wx::Event qw(
	EVT_SIZE
	EVT_IDLE );
use Pub::Utils;
use Pub::WX::Window;
use Pub::Buddy::buddyClientSession;
#use Pub::FS::SessionClient;
#use Pub::FS::fileClientResources;
#use Pub::FS::fileClientPane;
#use Pub::FS::fileClientHostDialog;
use base qw(Wx::Window Pub::WX::Window);


our $dbg_tab = 0;

my $PAGE_TOP = 40;
my $SPLITTER_WIDTH = 10;

my $instance = 0;

my $INITIAL_PORT = $ARGV[0];


#---------------------------
# new
#---------------------------

sub new
	# the 'data' member looks something like this
	# 	 session_name = 'TE(1)'
	# 	 arduino = '1'
	# 	 device_addr = '6'
	# 	 device_name = 'teensyExpression'
	# 	 file_server = '1'
	#    crlf = 1
	# 	 local_dir = '/src/Arduino/teensyExpression2/data'
	# 	 remote_dir = '/'
	# 	 remote_port = '50572'

{
	my ($class,$frame,$id,$book,$data) = @_;
	if (!$data)
	{
		error("No data specified");
		return;
	}
	$instance++;

	display($dbg_tab,0,"new winTab instance=$instance");
	display_hash($dbg_tab,0,"data",$data);
	my $this = $class->SUPER::new($book,$id);
	$this->MyWindow($frame,$book,$id,$data->{session_name},$data,$instance);
    $this->{name} = $data->{session_name};    # should already be done

	#---------------------------------------------------
	# if not the first instance, popup a buddyBox
	#---------------------------------------------------

	my $instance_port = $DEFAULT_PORT + $instance;
	my $command_line =
		$data->{device_addr}." ".
		($data->{arduino} ? "-arduino " : "").
		($data->{file_server} ? "-file_server " : "").
		($data->{crlf} ? "-crlf " : "").
		($instance != 1 ? "-server_port $instance_port ":"");

	if ($instance != 1)
	{
		# NOTE THE USE OF THE WINDOWS 'start' command to
		# instantiate a new dos box. Otherwise it comes
		# up in the same window!!

		# It is useless to write a file for the box_pid we get here,
		# as the actual process to kill is completely different, hence why
		# Therefore add another parameter to buddyBox command line that
		# takes the original parent buddyBox pid and the name of this
		# window and lets the child buddyBox write a pid file.

		my $parent_pid = $ARGV[1];
		$command_line .= "-parent $parent_pid $data->{session_name}";
			# add a double argument
			# the tab name can have no spaces, $'s or other things in it

		display($dbg_tab,-1,"STARTING buddyBox($command_line)");
		my $command = Cava::Packager::IsPackaged() ?
			"start ".Cava::Packager::GetBinPath()."/BuddyBox.exe $command_line" :
			"start perl /base/Pub/Buddy/BuddyBox.pm $command_line";

		$this->{box_pid} = system 1, $command;
		display($dbg_tab,0,"BuddyBox pid="._def($this->{box_pid}));


		# We need to wait until the session comes online

		my $try = 0;
		my $RETRIES = 5;
		while ($try < $RETRIES && !$this->{session})
		{
			sleep(1);
			$try++;
			display($dbg_tab,0,"connecting to new BuddyBox try=$try");
			$this->{session} = Pub::Buddy::buddyClientSession->new({
				PORT => $instance_port,
				NO_CONNECT_ERROR => 1});
		}
	}

	#---------------------------------------------------
	# otherwise connect to the main buddyBox
	#---------------------------------------------------

	else
	{
		$this->{session} = Pub::Buddy::buddyClientSession->new({
			PORT => $data->{remote_port}  });
	}


	#---------------------------------------------------
	# send command line to the main buddyBox
	#---------------------------------------------------

	if (!$this->{session})
	{
		error("Could not create client session!");
		return;
	}
	display($dbg_tab,-1,"client session started");
	if ($instance == 1)
	{
		$this->{session}->send_packet("CONFIG\t$command_line");
	}


	#---------------------------------------------------
	# continue
	#---------------------------------------------------
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
	display(0,1,"winTab::onClose() instance=$this->{instance} called");
	if ($this->{session} &&
		$this->{session}->isConnected())
	{
		$this->{session}->disconnect();
			# quiet (dont send EXIT) if it's the 1st instance
			# of the window, i.e. the primary buddyBox, cuz
			# that shuts down ITS server
	}
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

	if ($this->{session})
	{
		if ($this->{session}->{SOCK})
		{
			my $packet = $this->{session}->get_packet();
			if ($packet)
			{
				display($dbg_tab,-1,"got packet $packet");
				if ($packet eq 'EXIT')
				{
					display($dbg_tab,0,"onIdle() CLOSING $this->{name}!!");
					my $book = $this->GetParent();
					$book->closeBookPage($this);
				}
				elsif ($packet =~ /^KILL\t(.*)$/)
				{
					my $tab_name = $1;
					display($dbg_tab,0,"onIdle() KILLING $tab_name!!");
					$this->closeOtherPane($tab_name);
				}
			}
		}
	}

	# if the socket has gone away, we should close the tab.
	# if it's the 1st instance, we should close the app.

	$event->RequestMore(1);
}


sub closeOtherPane
{
	my ($this,$tab_name) = @_;
	my $frame = $this->{frame};
	display($dbg_tab,0,"closeOtherPane($tab_name)");

	my $found;
    for my $pane (@{$frame->{panes}})
	{
		if ($pane->{name} eq $tab_name)
		{
			$found = $pane;
			last;
		}
	}

	if ($found)
	{
		display($dbg_tab,1,"closing other pane($tab_name)");
		$found->{session}->{SOCK} = 0;
		my $book = $this->GetParent();
		$book->closeBookPage($found);
	}
	else
	{
		display($dbg_tab,1,"other pane($tab_name) not found!!");
	}
}




1;
