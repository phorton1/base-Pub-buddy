#-------------------------------------------
# uploadBinary - my binary protocol
#-------------------------------------------
package apps::buddy::buddyBinary;
use strict;
use warnings;
use Time::HiRes qw( sleep );

# as implemented in my circle/_prh/bootloader

my $BS_ACK = 'k';
my $BS_NAK = 'n';
my $BS_QUIT ='q';
my $BS_BLOCKSIZE = 2048;
my $BS_TIMEOUT = 500;


sub send32Binary
{
    my ($port,$value) = @_;
    for (my $i=3; $i>=0; $i--)
    {
        my $byte = $value >> ($i*8) & 0xff;
        # print "send32binary($byte)\n";
        $port->write(chr($byte));
    }
}


sub getAckNak
{
	my ($port) = @_;
    my $now = time();
    # print "getting acknack ...\n";
    while (time() < $now + $BS_TIMEOUT)
    {
        my ($bytes,$s) = $port->read(1);
        if ($bytes)
        {
            # print "Got acknak($s)\n";
            return substr($s,0,1);
        }
    }
    print "timed out getting acknak\n";
    return 0;
}


sub clearInputBuffer
{
	my ($port) = @_;
    my ($BlockingFlags, $InBytes, $OutBytes, $LatchErrorFlags) = $port->status();
    # print ">$BlockingFlags, $InBytes, $OutBytes, $LatchErrorFlags\n";
    my ($t1,$t2) = $port->read($InBytes) if $InBytes;
    $t2 = '' if !$t1;
    $t2 =~ s/\n|\r//g;
    print "clearing input buffer($t2) ...\n" if $t2;
}


sub uploadBinary
    # implements protocol as described in kernel.cpp
    # 	  <--- send 8 byte hex encoded length
    # 	  ---> receive ACK or QUIT
	# 	  <--- send filename, create and mod time
    # 	  ---> receive ACK or QUIT
	# repeat as necessary:
    # 	  <--- send packet (4 byte block_num, 2048 bytes, 2 byte checksum)
    # 	  ---> receive ACK, NAK, or QUIT
    #          resend packet if NAK, quit if QUIT
	# finish:
    # 	  <--- send 8 byte hex encoded checksum
    # 	  ---> receive ACK or QUIT
{
	my ($port,$filename) = @_;
    print "uploadBinary($filename)\n";
	if (!$port)
	{
		print "ERROR - no port/socket in uploadBinary\n";
		return;
	}

	$port->write(" ");
	sleep(0.5);

	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
	  	$atime,$mtime,$ctime,$blksize,$blocks) = stat($filename);

    if (!open(FH,"<$filename"))
    {
        print "ERROR - could get open $filename\n";
        return;
    }

    binmode(FH);
    my $data;
    my $bytes =  read (FH, $data, $size);
    close(FH);

    if ($bytes != $size)
    {
        print "ERROR - could not read expected: $size got $bytes\n";
        return;
    }


    print "sending size=$size\n";
    clearInputBuffer($port);
    send32Binary($port,$size);
    my $reply = getAckNak($port);
    return if !$reply || $reply ne $BS_ACK;

	# send the actual root filename

	$ctime = time();
	my $use_filename = $filename;  # "kernel_test.img";
	$use_filename =~ s/^.*\///;

	$mtime =
		(2019 	<< (16+9)) 	|
		(4 		<< (16+5)) 	|
		(6      << 16)		|
		(17     << 11)	    |
		(35     << 5) 		|
		11;

	#	The FAT date and time is a 32-bit value containing two 16-bit values:
	#		* The date (lower 16-bit).
	#		* bits 0 - 4:  day of month, where 1 represents the first day
	#		* bits 5 - 8:  month of year, where 1 represent January
	#		* bits 9 - 15: year since 1980
	#		* The time of day (upper 16-bit).
	#		* bits 0 - 4: seconds (in 2 second intervals)
	#		* bits 5 - 10: minutes
	#		* bits 11 - 15: hours

	print "sending filename($use_filename),mtime($mtime),and ctime now($ctime)\n";
    clearInputBuffer($port);
	$port->write($use_filename);
	$port->write(chr(0));
    send32Binary($port,$mtime);
    send32Binary($port,$ctime);
    $reply = getAckNak($port);
    return if !$reply || $reply ne $BS_ACK;

	my $addr = 0;
    my $num_retries = 0;
    my $total_sum = 0;
    my $block_num = 0;
    my $num_blocks = int(($size + $BS_BLOCKSIZE - 1) / $BS_BLOCKSIZE);
    while ($block_num < $num_blocks)
    {
redo_block:

        clearInputBuffer($port);

        my $part_sum = 0;
        my $left = $size - $addr;
        $left = $BS_BLOCKSIZE if $left > $BS_BLOCKSIZE;
        my $temp_sum = $total_sum;

        # printf("sending block($block_num)\n");
        send32Binary($port,$block_num);
        $reply = getAckNak($port);
        return if !$reply || ($reply ne $BS_ACK);

        # printf("checksum data $left at $addr ...\n");
        for (my $i=0; $i<$left; $i++)
        {
            my $c = substr($data,$addr + $i,1);
            $part_sum += ord($c);
            $temp_sum += ord($c);
            # $port->write($c);
        }

        # printf("sending data $left at $addr ...\n");
        $port->write(substr($data,$addr,$left));

        # printf("sending part_sum($part_sum)\n");
        send32Binary($port,$part_sum);

        $reply = getAckNak($port);
        return if !$reply || ($reply ne $BS_ACK && $reply ne $BS_NAK);
        if ($reply eq $BS_NAK)
        {
            print "--> retry($num_retries) block($block_num)\n";
            if ($num_retries++ > 5)
            {
                printf("ERROR - retry($num_retries) timeout on block($block_num)\n");
                return;
            }
            sleep(0.05);
            goto redo_block
        }

        $block_num++;
        $addr += $left; # $BS_BLOCKSIZE
        $total_sum = $temp_sum;
        $num_retries = 0;
    }

    print "sending data final checksum ($total_sum) ...\n";
    send32Binary($port,$total_sum);
    $reply = getAckNak($port);
    return if !$reply || ($reply ne $BS_ACK);

    print "upload finished sucessfully\n";
}


1;
