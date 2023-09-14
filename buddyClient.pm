#-------------------------------------------------
# Pub::Buddy::buddyClient
#--------------------------------------------------
# The Server Opens a socket and is called to check
# for incoming data onIdle()

package Pub::Buddy::buddyClient;
use strict;
use warnings;
use IO::Select;
use IO::Socket::INET;
use Time::HiRes qw(sleep);
use Pub::Utils;


our $dbg_client =  0;
	# 0 for main server startup
	# -1 for forking/threading details
	# -2 null reads
	# -9 for connection waiting loop
our $dbg_packet = 0;


BEGIN
{
 	use Exporter qw( import );
	our @EXPORT = qw(
		$dbg_client
		$dbg_packet
		getPacket
		sendPacket
	);
}



sub new
{
	my ($class,$port) = @_;
	my $this = { PORT => $port || 0 };
    bless $this,$class;
	$this = undef if !$this->connect();
	return $this;
}


sub connect
{
    my ($this) = @_;

	display($dbg_client,-1,"CLIENT connecting to port($this->{PORT})");

    $this->{SOCK} = IO::Socket::INET->new((
        PeerAddr => "localhost:$this->{PORT}",
        PeerPort => "http($this->{PORT})",
        Proto    => 'tcp' ));
    if (!$this->{SOCK})
    {
        error("CLIENT could not connect SERVER");
		return 0;
    }
	if (!$this->{PORT})
	{
		$this->{PORT} = $this->{SOCK}->sockport();
	}

	display($dbg_client,-1,"CLIENT connected on port($this->{PORT})");
	return 1;
}




#--------------------------------------------------
# packets
#--------------------------------------------------

sub sendPacket
{
    my ($this,$packet) = @_;

    if (length($packet) > 100)
    {
        display($dbg_packet,-1,"CLIENT --> ".length($packet)." bytes",1);
    }
    else
    {
        display($dbg_packet,-1,"CLIENT --> $packet",1);
    }

    my $sock = $this->{SOCK};
    if (!$sock)
    {
        error("CLIENT no socket in sendPacket");
        return;
    }

    if (!$sock->send($packet."\r\n"))
    {
        $this->{SOCK} = undef;
        error("CLIENT could not write to socket $sock");
        return;
    }

	$sock->flush();
    return 1;
}



sub getPacket
{
    my ($this) = @_;
    my $sock = $this->{SOCK};
    if (!$sock)
    {
        #error("CLIENT no socket in getPacket");
        return;
    }

	my $select = IO::Select->new($sock);
    return if !$select->can_read(0.1);

	my $CRLF = "\015\012";
	local $/ = $CRLF;

    my $packet = <$sock>;
    if (!defined($packet))
    {
        $this->{SOCK} = undef;
        error("CLIENT no response from peer");
        return;
    }

    $packet =~ s/(\r|\n)$//g;

    if (!$packet)
    {
        display($dbg_packet,0,"CLIENT empty response from peer");
        return;
    }

    if (length($packet) > 100)
    {
        display($dbg_packet,-1,"CLIENT <-- ".length($packet)." bytes",1);
    }
    else
    {
        display($dbg_packet,-1,"CLIENT <-- $packet",1);
    }

    return $packet;
}


1;
