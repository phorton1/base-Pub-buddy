#---------------------------------------------
# PreInstallApp.pm
#---------------------------------------------
# Script run directly from Cava Packager after building
# but before creating the installer.  This program reads
# and modifies the innosetup.iss file to make it work.

# Gleaned and Modified from examples in Program File (x86)/Innosetup
#
# Innosetup 5.5.9 specifics:
#
#     CloseApplications=force added
#     MinVersion=whatever removed
#     OutputManifestFile apparently no longer accepts a path
#     The Basque and Slovak languages are no longer available
#
# To run innosetup compiler from dos box
#   C:\Program Files (x86)\Cava Packager 2.0\innosetup\iscc /Qp C:\base_dist\cmManagerRelease\installer\innosetup.iss
#   /Qp = Quiet except for errors and warnings
#   /O- adds "syntax check only" but does delete the contents of the existing build
#   /O"/junk/test_installer" wipes out a different directory instead
# Komodo "Run" RE's Warning: (?P<file>.+?), Line (?P<line>\d+), Column (?P<content>.*))$
#

use strict;
use warnings;

my $USE_INNOSETUP_559 = 1;
    # Set to 1 to filter out and change lines that
    # Cava produces that are incompatible with
    # innotsetup 5.5.9 (and later) version(s).

my $USE_CAVA_POST_PL = 0;
    # Set to 0 to filter out Cava do-install calls

my $text = '';
my $in_language = 0;
my $installerdir = $ARGV[1];
my $unused_releaseddir = $ARGV[0];
my $iss_file = "$installerdir/innosetup.iss";

utf8::upgrade($text);

#---------------------------------------------------
# read the existing innosetup file and modify it
#---------------------------------------------------

open my $fh, "<$iss_file";
while(<$fh>)
{
    chomp;
    my $line = $_;

    $line = processLine($line);
    last if $line && $line eq '[Code]';
    $text .= "$line\n"
        if defined($line);
}
close($fh);

open $fh, ">$iss_file";
print $fh $text;
close($fh);


#----------------------------------------
# processLine
#----------------------------------------


sub commentLine
{
    my ($line) = @_;
    return "; following line auto-commented-out by PreInstallApp.pm\n; $line";
}


sub processLine
    # Do innotsetup 5.5.9u specific fixups
{
    my ($line) = @_;

	if ($in_language || $line eq '[Languages]')
    {
        $in_language = 1;
		$line = commentLine($line);
	}
    elsif ($line eq '[Setup]')
    {
        $line .= "\n".
            "DisableDirPage=yes\n".
            "ShowLanguageDialog=no\n".
            "DisableProgramGroupPage=yes\n".
            "RestartIfNeededByRun=no";

        $line .= "\n" .
            "CloseApplications=force\n".
            "OutputManifestFile=innosetup.manifest"
            if $USE_INNOSETUP_559;
    }
    elsif ($line =~ /^DisableDirPage=/ ||
           $line =~ /ShowLanguageDialog=/ ||
           $line =~ /^DisableProgramGroupPage=/ ||
           $line =~ /^RestartIfNeededByRun=/ ||
           $line =~ /^CloseApplications=/ ||
           $line =~ /^OutputManifestFile=/ ||
           $line =~ /^MinVersion=/ ||
           $line =~ /Basque|Slovak/)
    {
        $line = commentLine($line);  # undef;
    }
    elsif ($line =~ /\\bin\\do-install\.exe/ &&
           !$USE_CAVA_POST_PL)
    {
        $line = commentLine($line);  # undef;
    }

    return $line;
}


1;
