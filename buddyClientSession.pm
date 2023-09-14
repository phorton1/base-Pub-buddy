#-------------------------------------------------
# Pub::Buddy::buddyClientSession
#--------------------------------------------------
# The Server Opens a socket and is called to check
# for incoming data onIdle()

package Pub::Buddy::buddyClientSession;
use strict;
use warnings;
use Pub::Utils;
use Pub::FS::SessionClient;
use base qw(Pub::FS::SessionClient);

our $dbg_client =  0;
	# 0 for main server startup
	# -1 for forking/threading details
	# -2 null reads
	# -9 for connection waiting loop
our $dbg_packet = 0;


BEGIN
{
 	use Exporter qw( import );
	our @EXPORT = (
		qw(),
        @Pub::FS::SessionClient::EXPORT,
	);
}



sub new
{
	my ($class,$params) = @_;
	$params ||= {};
	$params->{PORT} ||= 0;
	$params->{NOBLOCK} = 1;
	my $this = $class->SUPER::new($params);
	return if !$this;
    bless $this,$class;
	return $this;
}



1;
