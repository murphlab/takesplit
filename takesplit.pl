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

printReport($sets);


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

	my $previousEpoch;
	my $previousSubSecEpoch;

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
		
		my $interval = -999;
		my $subSecInterval = -999;
		if (defined $previousEpoch) {
			$interval = $epoch - $previousEpoch;
			$subSecInterval = $subSecEpoch - $previousSubSecEpoch;
		}
		$previousEpoch = $epoch;
		$previousSubSecEpoch = $subSecEpoch;
		
		push @imageData, { 
					file => $inFile, 
					epoch => $epoch, 
					subSecEpoch => $subSecEpoch, 
					interval => $interval, 
					subSecInterval => $subSecInterval  
				};
	}


	# force non-subsec as it seems inaccurate:
	my $epochKey = "epoch";
	my $intervalKey = "interval";

	my @sortedImageData = sort { $a->{$epochKey} <=> $b->{$epochKey} } @imageData;

	return { epochKey => $epochKey, intervalKey => $intervalKey, images => \@sortedImageData };
}

sub analyzeImageData
{
	my $imageData = shift;
	my @sets;
	my $intervalSum = 0;
	for my $image (@{$imageData->{images}}) {

		print Dumper($image);

		if (!@sets) {
			print "No sets, creating new set\n";
			push @sets, { images => [ $image ] };
		} else {
			my $currentSet = $sets[ $#sets ];
			
			my $previousImage = ${$currentSet->{images}}[ $#{$currentSet->{images}} ];

			my $interval = $image->{$imageData->{intervalKey}};
			
			#print "interval: $interval\n";
			
			if (!$currentSet->{baseInterval}) {

				print "BaseInterval for current set NOT defined";
	
				$currentSet->{baseInterval} = $interval;
				push @{$currentSet->{images}}, $image;

			} else {

				#print "BaseInterval for current set IS defined";

				my $tolerance = $imageData->{epochKey} eq "epoch" ? 2.0 : 0.2;
				if ( abs( $currentSet->{baseInterval} - $interval ) > $tolerance ) {

					print "Greater than tolerance";

					$currentSet->{intervalAverage} = $intervalSum / $#{$currentSet->{images}};
					$intervalSum = 0;

					push @sets, { images => [ $previousImage, $image ], baseInterval => $interval };	

				} else {

					push @{$currentSet->{images}}, $image;
				}
			}
			$intervalSum += $interval;
		}
	}
	return \@sets;
}

sub printReport
{
	my $sets = shift;
	my $setCount = $#{$sets};
	print "SUMMARY\n";
	print "=======\n";
	print "Number of sets: $setCount\n";
	for my $set (@{$sets}) {
		my $imageCount = scalar @{$set->{images}};
		my $baseInterval = $set->{baseInterval};
		my $intervalAverage = $set->{intervalAverage};
		my $firstImage = Dumper(${$set->{images}}[0]);
		my $lastImage = Dumper(${$set->{images}}[ $#{$set->{images}} ]);
		my $allImages = Dumper( $set->{images} );
		print <<END;
SET
---
Base interval: 		$baseInterval
Interval average: 	$intervalAverage
Image count:		$imageCount
Images:
$allImages

END


	}
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

