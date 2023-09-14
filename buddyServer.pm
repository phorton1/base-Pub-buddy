#-------------------------------------------------
# Pub::Buddy::buddyServer
#--------------------------------------------------
# The Server Creates a socket and listens for connections.
# it creates buddySessions that maintain a link to the
# application.
#
# Tt can maintain multiple sessions to allow the same COM_PORT
# to be used with multiple Tabs in the app,

# It can receive configurations from the App and push
# information to it.  Push notifications can include
# SSDP notifications from the initial Buddy Box for SSDP,
# or for any box about status changes (i.e. Connection Lost,
# In Artduino Build, etc.
#
# As well as receiving configurations, it, or more properly
# the buddySession, can act as a fileServer for those devices
# and Application tabs that support it.

package Pub::Buddy::buddyServer;
use strict;
use warnings;
use threads;
use threads::shared;
use IO::Select;
use IO::Socket::INET;
use Time::HiRes qw(sleep);
use Pub::Utils;
use Pub::FS::RemoteServer;
use Pub::Buddy::buddyServerSession;
use base qw(Pub::FS::RemoteServer);


BEGIN {
    use Exporter qw( import );
	our @EXPORT = (
		qw (),
	    # forward base class exports
        @Pub::FS::RemoteServer::EXPORT,
	);
};



sub new
{
    my ($class,$params) = @_;
	$params ||= shared_clone({});
	$params->{PORT} ||= 0;
    my $this = $class->SUPER::new($params);
	return if !$this;
    bless $this,$class;
	return $this;
}


sub createSession
	# this method overriden in derived classes
	# to create different kinds of sessions
{
	my ($this,$sock) = @_;
	return Pub::Buddy::buddyServerSession->new({
		SOCK => $sock,
		IS_SERVER => 1 });
}



1;
