#!/usr/bin/perl
#-------------------------------------------------------------------------
# the main application object
#-------------------------------------------------------------------------

package Pub::Buddy::BuddyApp;
use strict;
use warnings;
use Wx qw(:everything);
use Wx::Event qw(EVT_MENU);
use Pub::Utils;
use Pub::WX::Frame;
use Pub::Buddy::appResources;
use Pub::Buddy::winTab;
use base qw(Pub::WX::Frame);

my $dbg_app = 0;


$data_dir = '/base/temp';	# currently unused
$temp_dir = '/base/temp';

# $logfile = "$temp_dir/Buddy.log";

$Pub::WX::AppConfig::ini_file = "$temp_dir/Buddy.ini";
unlink $Pub::WX::AppConfig::ini_file;

my $INITIAL_PORT = $ARGV[0];
my $PARENT_PID = $ARGV[1];


#-----------------------------------------------------
# methods
#-----------------------------------------------------

sub new
{
	my ($class, $parent) = @_;
	my $this = $class->SUPER::new($parent);
	return $this;
}


sub onInit
    # derived classes MUST call base class!
{
    my ($this) = @_;
    $this->SUPER::onInit();
	EVT_MENU($this, $COMMAND_CONNECT, \&commandConnect);
	return if !$this->createPane($ID_CLIENT_WINDOW,undef,{
			remote_port => $INITIAL_PORT,
			session_name => "TE(1)",
			device_addr => 3,
			device_name => 'teensyExpression',
			arduino => 1,
			file_server => 1,
			local_dir => '/src/Arduino/teensyExpression2/data',
			remote_dir => '/',
		});
    return $this;
}


sub createPane
	# we never save/restore any windows
	# so config_str is unused
{
	my ($this,$id,$book,$data,$config_str) = @_;
	display($dbg_app,0,"BuddyApp::createPane($id)".
		" book="._def($book).
		" data="._def($data));

	if ($id == $ID_CLIENT_WINDOW)
	{
		return error("No name specified in BuddyApp::createPane()") if !$data;
	    $book = $this->getOpenDefaultNotebook($id) if !$book;
        return Pub::Buddy::winTab->new($this,$id,$book,$data);
    }
    return $this->SUPER::createPane($id,$book,$data,$config_str);
}


sub commandConnect
{
	my ($this,$event) = @_;
	return if !$this->createPane($ID_CLIENT_WINDOW,undef,{
			remote_port => 0,
			session_name => "CLOCK(1)",
			device_addr => '10.237.50.12',
			device_name => 'theClock3.3',
			crlf => 1,
		});

}


#----------------------------------------------------
# CREATE AND RUN THE APPLICATION
#----------------------------------------------------

package buddyApplication;
use strict;
use warnings;
use Pub::Utils;
use Pub::WX::Main;
use base 'Wx::App';


my $frame;


sub OnInit
{
	$frame = Pub::Buddy::BuddyApp->new();
	unless ($frame) {print "unable to create BuddyApp"; return undef}
	$frame->Show( 1 );
	display(0,0,"BuddyApp.pm started PARENT_PID=$PARENT_PID this_pid=$$");
	return 1;
}

my $app = buddyApplication->new();
Pub::WX::Main::run($app);

# This little snippet is required for my standard
# applications (needs to be put into)

display(0,0,"ending BuddyApp.pm ...");
$frame->DESTROY() if $frame;
$frame = undef;
display(0,0,"finished BuddyApp.pm");




1;
