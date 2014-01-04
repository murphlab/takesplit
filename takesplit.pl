#!/usr/bin/perl

use strict;

my $exeDir;
BEGIN {
    # get exe directory
    $exeDir = ($0 =~ /(.*)[\\\/]/) ? $1 : '.';
    # add lib directory at start of include path
    unshift @INC, "$exeDir/lib";
}

use Image::ExifTool qw(:Public);
use Getopt::Std;
use Data::Dumper;
use Time::Local;

my $USAGE = <<END;
USAGE: $0 -i <inputDir> -o <outputDir>
END

my %o=();
getopts("i:o:",\%o);

my $inputDir = $o{i};
my $outputDir = $o{o};

die $USAGE unless $inputDir and $outputDir;
die "inputDir must be a directory" unless -d $inputDir;
die "outputDir must be a directory" unless -d $outputDir;

my $imageData = loadImageData();

my $sets = analyzeImageData($imageData);

print "Number of sets: $#{$sets}\n";


########
# Subs #
########

sub loadImageData 
{
	my @inFiles = (<$inputDir/*>);
	my $inFileCount = scalar @inFiles;

	print "Read $inFileCount inFiles\n";

	my $subSecAvailable = 1; 

	my @imageData;

	for my $inFile (@inFiles) {
		print "$inFile\n";
		my $exif = ImageInfo($inFile);
		my $exifError = $exif->{Error};
		if ($exifError) {
			print STDERR "Could not read EXIF data from file: $inFile error: $exifError\n";
			next;
		}
		my $exifWarning = $exif->{Warning};
		if ($exifWarning) {
			print STDERR "File: $inFile warning: $exifWarning";
		}
		my $dateTimeOrig = $exif->{DateTimeOriginal};
		my $subSecDateTimeOrig = $exif->{SubSecDateTimeOriginal};
		if (!$dateTimeOrig) {
			die "DateTimeOriginal EXIF tag not found in file:\"$inFile\" . Exiting";
		}
		if (!$subSecDateTimeOrig) {
			$subSecAvailable = 0;	
		}
		my $epoch = dateTimeToEpoch($dateTimeOrig);
		my $subSecEpoch = dateTimeToEpoch($subSecDateTimeOrig);
		push @imageData, { file => $inFile, epoch => $epoch, subSecEpoch => $subSecEpoch };
	}

#	my $epochKey;
#	if ($subSecAvailable) {
#		print "SubSecDateTimeOriginal available (subsecond resolution)\n";
#		$epochKey = "subSecEpoch";
#	} else {
#		print "SubSecDateTimeOriginal not avaialbe so using DateTimeOriginal (one-second resolution)\n";
#		$epochKey = "epoch";
#	}

	my $epochKey = "epoch";

	my @sortedImageData = sort { $a->{$epochKey} <=> $b->{$epochKey} } @imageData;

	return { epochKey => $epochKey, images => \@sortedImageData };
}

sub analyzeImageData
{
	my $imageData = shift;
	my @sets;
	for my $image (@{$imageData->{images}}) {

		print Dumper($image);

		if (!@sets) {
			print "No sets, creating new set\n";
			push @sets, { images => [ $image ] };
		} else {
			my $currentSet = $sets[ $#sets ];
			
			my $previousImage = ${$currentSet->{images}}[ $#{$currentSet->{images}} ];

			#print "previousImage: ", Dumper($previousImage);

			my $interval = $image->{$imageData->{epochKey}} - $previousImage->{$imageData->{epochKey}}; 

			print "interval: $interval\n";
			
			if (!$currentSet->{interval}) {
	
				$currentSet->{interval} = $interval;
				push @{$currentSet->{images}}, $image;

			} else {

				my $tolerance = $imageData->{epochKey} eq "epoch" ? 2.0 : 0.2;
				if ( abs( $currentSet->{interval} - $interval ) > $tolerance ) {

					push @sets, { images => [ $previousImage, $image ], interval => $interval };	

				} else {

					push @{$currentSet->{images}}, $image;
				}
			}
		}
	}
	return \@sets;
}

sub dateTimeToEpoch
{
	# eg: 2013:12:31 22:32:42
	my $dateTime = shift;
	my ($date,$time) = split /\s/, $dateTime;
	my ($year, $month, $day) = split /:/, $date;
	my ($hour, $minute, $second) = split /:/, $time;
	my $epoch = timelocal(0,$minute,$hour,$day,$month-1,$year) + $second;
	return $epoch;
}

