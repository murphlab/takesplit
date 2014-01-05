#!/usr/bin/perl

# TODO
# - report only mode: doesn't copy files

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

################
# Main Program #
################

my $DEFAULT_MINIMUM_FRAMES = 3;

my $USAGE = <<END;
USAGE: $0 -i <inputDir> -o <outputDir> [-m <minimum frames per sequence (default $DEFAULT_MINIMUM_FRAMES)>]
END

my %o=();
getopts("i:o:m:",\%o);

my $inputDir = $o{i};
my $outputDir = $o{o};
my $minFrames = $o{m} ? $o{m} : $DEFAULT_MINIMUM_FRAMES;

die $USAGE unless $inputDir and $outputDir;
die "inputDir must be a directory" unless -d $inputDir;
die "outputDir must be a directory" unless -d $outputDir;

my @inFiles = (<$inputDir/*>);

my $imageData = loadImageData(\@inFiles);

my $sets = analyzeImageData($imageData);

copyFilesToOutputDir( \@inFiles, $sets );

########
# Subs #
########

sub loadImageData 
{
	my $inFilesRef = shift;

	my $inFileCount = scalar @{$inFilesRef};

	print "Read $inFileCount inFiles\n";

	my $subSecAvailable = 1; 

	my @imageData;
	for my $inFile (@{$inFilesRef}) {
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
		
		push @imageData, { 
					file => $inFile, 
					epoch => $epoch, 
					subSecEpoch => $subSecEpoch, 
					dateTimeOriginal => $dateTimeOrig,
					subSecDateTimeOriginal => $subSecDateTimeOrig
				};
	}

	# force non-subsec as it seems inaccurate:
	my $epochKey = "epoch";

	my @sortedImageData = sort { $a->{$epochKey} <=> $b->{$epochKey} } @imageData;

	return { epochKey => $epochKey, images => \@sortedImageData };
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

			my $interval = $image->{$imageData->{epochKey}} - $previousImage->{$imageData->{epochKey}};

			$image->{interval} = $interval;
			
			#print "interval: $interval\n";
			
			if (!$currentSet->{baseInterval}) {

				print "BaseInterval for current set NOT defined";
	
				$currentSet->{baseInterval} = $interval;
				push @{$currentSet->{images}}, $image;

			} else {

				#print "BaseInterval for current set IS defined";

				$currentSet->{intervalAverage} = $intervalSum / $#{$currentSet->{images}};

				my $tolerance = $imageData->{epochKey} eq "epoch" ? 2.0 : 0.2;
				if ( abs( $currentSet->{baseInterval} - $interval ) > $tolerance ) {

					print "Greater than tolerance";

					$intervalSum = 0;

					push @sets, { images => [ $previousImage, $image ], baseInterval => $interval };	

				} else {

					push @{$currentSet->{images}}, $image;
				}
			}
			$intervalSum += $interval;
		}
	}

	my @setsWithMinFrames = grep { @{$_->{images}} >= $minFrames } @sets;

	return \@setsWithMinFrames;
}

sub copyFilesToOutputDir
{
	my $inFilesRef = shift;
	my $sets = shift;

	my $setCount = scalar @{$sets};	
	my $lastSet = $setCount - 1;
	my $digitCount = length $lastSet;

	print <<END;
SET COUNT:	$setCount

END

	my %fileHash;
	for my $file (@{$inFilesRef}) {
		$fileHash{$file} = 1;
	}
	
	my $lastImageOfPreviousSet;
	my $repeatCount = 0;

	my $i = 0;
	for my $set (@{$sets}) {
		my $dirName = sprintf( "%0${digitCount}d", $i++ );
		my $numFiles = scalar @{$set->{images}};
		my $firstFile = ${$set->{images}}[0];
		my $lastFile = ${$set->{images}}[$numFiles - 1];
		
		my $firstFileInPrevSet = ($firstFile->{file} eq $lastImageOfPreviousSet);		
		$lastImageOfPreviousSet = $lastFile->{file};
		my $flag = $firstFileInPrevSet ? "*" : "";
		$repeatCount++ if $firstFileInPrevSet; 

		# todo loop over images and copy

		print <<END;
DIRECTORY: 	$dirName
FILE COUNT:	$numFiles
STARTS:		$firstFile->{dateTimeOriginal}
ENDS:		$lastFile->{dateTimeOriginal}
INTERVAL AVG:	$set->{intervalAverage}
FIRST FILE:	$firstFile->{file} $flag
LAST FILE:	$lastFile->{file}

END
	}
	if ($repeatCount) {
		print <<END;
* Indicates files with ambiguous intervals repeated across sets.

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

