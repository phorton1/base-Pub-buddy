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
#use Pub::Buddy::buddySession;


our $dbg_server:shared =  -1;
	# 0 for main server startup
	# -1 for forking/threading details
	# -2 null reads
	# -9 for connection waiting loop
our $dbg_packets = 0;


BEGIN
{
 	use Exporter qw( import );
	our @EXPORT = qw(
		$dbg_server
		$dbg_packets
		$INITIAL_PORT
		pushNotification
	);
}


our $INITIAL_PORT:shared;


my $USE_FORKING = 1;
my $KILL_FORK_ON_PID = 1;

# following only if !$USE_FORKING

my @client_threads = (0,0,0,0,0,0,0,0,0,0);
my $client_thread_num = 0;
     # ring buffer to keep threads alive at
     # least until the session gets started

my $server_thread = undef;
my $connect_num = 0;
	# the initial connection will send system like
	# notification


my @notifications:shared;
sub pushNotification
{
	my ($packet) = @_;
	display($dbg_packets+1,-1,"pushNotification($packet)");
	push @notifications,$packet;
}



sub new
{
	my ($class,$params) = @_;
	$params ||= {};
	my $this = shared_clone($params);
	$this->{running} = 0;
	$this->{stopping} = 0;
    bless $this,$class;
	$this = undef if !$this->start();
	return $this;
}


# sub createSession
# 	# this method overriden in derived classes
# 	# to create different kinds of sessions
# {
# 	my ($this,$sock) = @_;
# 	return Pub::FS::Session->new({
# 		SOCK => $sock,
# 		IS_SERVER => 1 });
# }


sub inc_running
{
    my ($this) = @_;
	$this->{running}++;
	display($dbg_server+1,0,"inc_running($this->{running})");
}


sub dec_running
{
    my ($this) = @_;
	$this->{running}-- if $this->{running};
	display($dbg_server+1,0,"dec_running($this->{running})");
}



sub stop
{
    my ($this) = @_;
    my $TIMEOUT = 5;
    my $time = time();
    $this->{stopping} = 1;
    while ($this->{running} && time() < $time + $TIMEOUT)
    {
        display($dbg_server,0,"waiting for file buddyServer on port($this->{PORT}) to stop");
        sleep(1);
    }
    if ($this->{running})
    {
        error("STOPPED with $this->{running} existing threads");
    }
    else
    {
        LOG(0,"STOPPED sucesfully");
    }
}


sub start
{
    my ($this) = @_;
    display($dbg_server+1,0,"buddyServer::start()");
	if (!$this->{PORT})
	{
		warning($dbg_server,0,ref($this)." PORT NOT SPECIFIED");
	}
	else
	{
		display($dbg_server,0,ref($this)." STARTING on port($this->{PORT})");
	}
    $this->inc_running();
    $server_thread = threads->create(\&serverThread,$this);
    $server_thread->detach();
    return $this;
}



sub serverThread
{
    my ($this) = @_;

    my $server_socket = IO::Socket::INET->new(
        LocalPort => $this->{PORT} || 0,
        Type => SOCK_STREAM,
        Reuse => 1,
        Listen => 10);

    if (!$server_socket)
    {
        $this->dec_running();
        error("Could not create server socket: $@");
        return;
    }

	if (!$this->{PORT})
	{
		$INITIAL_PORT = $server_socket->sockport();
		$this->{PORT} = $INITIAL_PORT;
		display($dbg_server,0,"initial SERVER STARTED ON PORT($INITIAL_PORT)");
	}


    # loop accepting connectons from clients

    my $WAIT_ACCEPT = 1;
    display($dbg_server+1,1,'Waiting for connections ...');
    my $select = IO::Select->new($server_socket);
    while ($this->{running} && !$this->{stopping})
    {
        if ($USE_FORKING)
        {
            if (opendir DIR,$temp_dir)
            {
                my @entries = readdir(DIR);
                closedir DIR;
                for my $entry (@entries)
                {
                    if ($entry =~ /^((-|\d)+)\.pfs_pid/)
                    {
                        my $pid = $1;

						if ($KILL_FORK_ON_PID)
						{
							display($dbg_server+1,0,"KILLING CHILD PID $pid");
							unlink "$temp_dir/$entry";
							kill(15, $pid);		# SIGTERM
						}
						else
						{
							display($dbg_server+1,0,"FS_FORK_WAITPID(pid=$pid)");
							my $got = waitpid($pid,0);  # 0 == WNOHANG
							if ($got && $got ==$pid)
							{
								unlink "$temp_dir/$entry";
							}
						}
                    }
                }
            }
        }
        if ($select->can_read($WAIT_ACCEPT))
        {
            $connect_num++;
            my $client_socket = $server_socket->accept();
            binmode $client_socket;

            my $peer_addr = getpeername($client_socket);
            my ($peer_port,$peer_raw_ip) = sockaddr_in($peer_addr);
            my $peer_name = gethostbyaddr($peer_raw_ip,AF_INET);
            my $peer_ip = inet_ntoa($peer_raw_ip);
            $peer_name = '' if (!$peer_name);

            $this->inc_running();

            if ($USE_FORKING)
            {
                display($dbg_server+1,1,"fs_fork($connect_num) ...");
                my $rslt = fork();
                if (!defined($rslt))
                {
                    $this->inc_running(-1);
                    error("FS_FORK($connect_num) FAILED!");
                    next;
                }

                if (!$rslt)
                {
                    display($dbg_server+1,0,"FS_FORK_START($connect_num) pid=$$");

                    $this->sessionThread($connect_num,$client_socket,$peer_ip,$peer_port);

                    display($dbg_server+1,0,"FS_FORK_END($connect_num) pid=$$");

					if (!$KILL_FORK_ON_PID)
					{
						open OUT, ">$temp_dir/$$.pfs_pid";
						print OUT $$;
						close OUT;
					}

                    exit(0);
                }
                display($dbg_server+1,1,"fs_fork($connect_num) parent continuing");

            }
            else
            {
                display($dbg_server+1,1,"starting sessionThread");
                $client_threads[$client_thread_num] = threads->create(
                    \&sessionThread,$this,$connect_num,$client_socket,$peer_ip,$peer_port);
                $client_threads[$client_thread_num]->detach();
                $client_thread_num++;
                $client_thread_num = 0 if $client_thread_num > @client_threads-1;
                display($dbg_server+1,1,"back from starting sessionThread");
            }
        }
        else
        {
            display($dbg_server+2,0,"not can_read()");
        }
    }

    $server_socket->close();
    LOG(0,"serverThread STOPPED");
    $this->dec_running();

}   # serverThread()




sub sessionThread
{
    my ($this,$connect_num,$client_sock,$peer_ip,$peer_port) = @_;
    display($dbg_server+1,0,"FILE SESSION THREAD");
	# $this->{SOCK} = $client_sock;

    #---------------------------------------------
    # process packets until exit
    #---------------------------------------------

	my $ok = 1;
    my $rslt = -1;
	my $select = IO::Select->new($client_sock);
    while ($ok && !$this->{stopping})
    {
		# print "serverLoop\n";

		if ($select->can_read(1))
		{
			# print "can read\n";
			my $packet = getPacket($client_sock);
			last if $this->{stopping};
			next if !defined($packet);

			# PROCESS THE PACKET

			if ($packet =~ /ABORT/)
			{
				next;
			}
			elsif ($packet =~ /^EXIT/)
			{
				last;
			}
			# else
			# {
			# 	my @params = split(/\t/,$packet);
            #
			# 	print "SERVER PACKET $packet\n";
			# 	my $rslt = $session->doCommand($params[0],!$this->{IS_REMOTE},$params[1],$params[2],$params[3]);
			# 	my $packet = ref($rslt) ? $session->listToText($rslt) : $rslt;
			# 	last if $packet && !$session->send_packet($packet);
			# }
		}

		if ($connect_num == 1 &&		# intialial connection
		 	@notifications)
		{
		 	sendPacket($client_sock,shift @notifications);
		}
    }

	display($dbg_server,0,"SERVER SESSION THREAD STOPPING");

	undef $this->{SOCK};
    $client_sock->close();
    $this->dec_running();

	if (!$KILL_FORK_ON_PID)
	{
		open OUT, ">$temp_dir/$$.pfs_pid";
		print OUT $$;
		close OUT;
	}

	while (1) { sleep(10); }

	# return;
	# exit(0);
}



#--------------------------------------------------
# packets
#--------------------------------------------------


sub sendPacket
{
    my ($sock,$packet) = @_;

    if (length($packet) > 100)
    {
        display($dbg_packets,-1,"SERVER --> ".length($packet)." bytes",1);
    }
    else
    {
        display($dbg_packets,-1,"SERVER --> $packet",1);
    }

    if (!$sock->send($packet."\r\n"))
    {
        error("SERVER could not write to socket $sock");
        return;
    }

	$sock->flush();
    return 1;
}



sub getPacket
{
    my ($sock) = @_;

	my $CRLF = "\015\012";
	local $/ = $CRLF;

    my $packet = <$sock>;
    if (!defined($packet))
    {
        # $this->{SOCK} = undef;
        # error("SERVER no response from peer");
        return;
    }

    $packet =~ s/(\r|\n)$//g;

    if (!$packet)
    {
        error("SERVER empty response from peer");
        return;
    }

    if (length($packet) > 100)
    {
        display($dbg_packets,-1,"SERVER <-- ".length($packet)." bytes",1);
    }
    else
    {
        display($dbg_packets,-1,"SERVER <-- $packet",1);
    }

    return $packet;
}


1;
