#-------------------------------------------
# cnc3018 screen grabber
#-------------------------------------------

package buddy_Grab;
use strict;
use warnings;


BEGIN
{
 	use Exporter qw( import );
	our @EXPORT = qw(

		$in_screen_grab
		$screen_grab
		$grab_width
		$grab_height

		handleScreenGrab
	);
}



our $in_screen_grab = 0;
our $screen_grab;
our $grab_width = 0;
our $grab_height = 0;
my $last_grab_pct = 0;

sub handleScreenGrab
{
	my ($c) = @_;

	$screen_grab .= $c;
	$in_screen_grab--;

	my $len = length($screen_grab);
	my $pct = int($len * 100 / ($grab_width * $grab_height * 3));
	if ($last_grab_pct != $pct)
	{
		$last_grab_pct = $pct;
		display(0,0,"SCREEN_GRAB $pct percent complete");
	}
	if (!$in_screen_grab)
	{
		dump_screen_grab();
	}
}


sub dump_screen_grab
	# could add a timeout if it goes awry ..
{
	my $len = $grab_width * $grab_height * 3;
	display(0,0,"dumping SCREEN_GRAB($grab_width X $grab_height)  len=".length($screen_grab));
	if ($len != length($screen_grab))
	{
		display(0,0,"HMM len($len) != length(screen_grab)=".length($screen_grab));
	}
	my $file_len = 54 + $len;

	my @bmp_header = (
		ord('B'),ord('M'),          # signature
		# file size in bytes (LSB first) = 230,454 = 0x38436
		$file_len & 0xff,  ($file_len>>8) & 0xff, ($file_len>>16) & 0xff, ($file_len>>24) & 0xff,
		0,  0,
		0,  0,
		54, 0, 0, 0,                # offset from beginning of file to pixel data

		# DIB (image information) header (40 bytes)

		40,   0, 0, 0,              # size of DIB = 40 bytes
		# width of image (320 = 0x00000140)
		$grab_width & 0xff, ($grab_width>>8) & 0xff, ($grab_width>>16), ($grab_width>>24),
		# height of image (240 = 0xf0)
		$grab_height & 0xff, ($grab_height>>8) & 0xff, ($grab_height>>16) & 0xff, ($grab_height>>24) & 0xff,
		1,  0,                      # number of planes in image
		24, 0,                      # number of bits per pixel (LSB first)
		0,0,0,0,                    # compression == 0
		0,0,0,0,                    # size of compressed image == 0 when no compression used
		0,0,0,0,                    # XpixelsPerMeter (resolution) 0 = no preference
		0,0,0,0,                    # YpixelsPerMeter (resolution) 0 = no preference
		0,0,0,0,                    # number of colors in palette (0 == raw pixel data)
		0,0,0,0 );                  # number of "important" colors in palette (0 == generally ignored)

	my $ofile;
	my $filename;
	my $file_num = 1;
	my $ok = 0;

	while (!$ok)
	{
		# $filename = "/junk/screen_grab_".($file_num++).".bmp";
		$filename = sprintf("/junk/screen_grab_%03d.bmp",$file_num++);
		$ok = !-f $filename;
	}
	if (open($ofile,">$filename"))
	{
		display(0,0,"writing screen grab to $filename");

		binmode $ofile;
		for my $c (@bmp_header)
		{
			print $ofile chr($c);
		}
		print $ofile $screen_grab;
		close $ofile;
	}
	else
	{
		display(0,0,"Could not open $filename for writing");
	}

}



1;
