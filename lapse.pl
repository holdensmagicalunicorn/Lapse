#!/usr/bin/perl
use warnings;
use strict;
use Time::Duration;
use Data::Dumper;
use Carp;
use Getopt::Long;
use File::Copy qw/move/;


sub usage {
	print "USAGE: $0 <NAME> -I <interval> [-F <numframes> | -D <duration>] [--hookscript=/path/to/script]\n";
	exit(1);
}

our %opt;
our ($interval, $numframes, $duration, $fps); # Commonly used options
$fps = 20;

GetOptions(\%opt,
	'hookscript|H=s', 'interval|I=i' => \$interval,
	'numframes|F=i' => \$numframes, 'duration|D=i' => \$duration,
	'fps=i' => \$fps
) or usage();

if (@ARGV < 1) {
	usage();
} 
#CONFIG
##HOOK="capture_hook.pl"

#ARGUMENTS
my $Name = $ARGV[0];

if ( -d $Name ) {
	print "$Name/ already exists, won't ovewrite.  Giving up.\n";
	exit(1);
}

#SETUP
mkdir($Name) or croak($!);
chdir($Name) or croak($!);

if ($duration) {
	if ($numframes) { print "Ignoring specified numframes in favour of duration argument\n"; }
	$numframes = $duration * $fps;
} else {
	unless($interval && $numframes) {
		# Nothing is set, default to 15/30
		$interval = 15; 
		$numframes = 30;
	}
}

for (<capt*.jpg>) {
	unlink($_);
}
print "Taking photos every $interval seconds\n";

#CAPTURE
# Settings used for Canon EOS 400D
# $ gphoto2 --get-config imageformat
# 		Label: Image Format                                                            
# 		Type: RADIO
# 		Current: Small Normal JPEG
# 		Choice: 0 Large Fine JPEG
# 		Choice: 1 Large Normal JPEG
# 		Choice: 2 Medium Fine JPEG
# 		Choice: 3 Medium Normal JPEG
# 		Choice: 4 Small Fine JPEG
# 		Choice: 5 Small Normal JPEG
# 		Choice: 6 RAW
# 		Choice: 7 RAW + Large Fine JPEG
#
# $ gphoto2 --get-config capturetarget
#		Label: Capture Target                                                          
#		Type: RADIO
#		Current: Internal RAM
#		Choice: 0 Internal RAM
#		Choice: 1 Memory card


system('gphoto2',
	"-F$numframes",
	"-I$interval",
	($opt{hookscript} ? "--hook-script=$opt{hookscript}" : ''),
	qw{ --set-config imageformat=5 --set-config capturetarget=0 --set-config capture=on --capture-image-and-download }
);

#ENCODE
if ( -f 'capt0000.jpg' ) {
	system('ffmpeg', '-r', $fps, '-i', 'capt%04d.jpg', '-target', 'pal-dvd', 'cap.mpg');
} else {
	croak "Failed to save images for some reason? $!";
}


#PLAY
if ( -f 'cap.mpg' ) {
	system('mplayer', 'cap.mpg', '-loop', '0');
	move('cap.mpg', "$Name.mpg");
}
