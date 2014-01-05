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
my $UNUSED_FILE_DIR = "noset";

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

	print <<END;
INFILE COUNT: 	$inFileCount

END
	my $subSecAvailable = 1; 

	my @imageData;
	for my $inFile (@{$inFilesRef}) {
		print STDERR  ".";
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
	print STDERR " Done.\n\n";

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

		if (!@sets) {
			push @sets, { images => [ $image ] };
		} else {
			my $currentSet = $sets[ $#sets ];
			
			my $previousImage = ${$currentSet->{images}}[ $#{$currentSet->{images}} ];

			my $interval = $image->{$imageData->{epochKey}} - $previousImage->{$imageData->{epochKey}};

			$image->{interval} = $interval;
			
			if (!$currentSet->{baseInterval}) {

				$currentSet->{baseInterval} = $interval;
				push @{$currentSet->{images}}, $image;

			} else {

				$currentSet->{intervalAverage} = $intervalSum / $#{$currentSet->{images}};

				my $tolerance = $imageData->{epochKey} eq "epoch" ? 2.0 : 0.2;
				if ( abs( $currentSet->{baseInterval} - $interval ) > $tolerance ) {

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
	#my $lastSet = $setCount - 1;
	#my $digitCount = length $lastSet;

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
		#my $dirName = sprintf( "%0${digitCount}d", $i++ );
		my $numFiles = scalar @{$set->{images}};
		my $firstFile = ${$set->{images}}[0];
		my $lastFile = ${$set->{images}}[$numFiles - 1];

		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($firstFile->{epoch});
		my $dirName = sprintf("%4d-%02d-%02d-%02d-%02d-%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
		
		my $firstFileInPrevSet = ($firstFile->{file} eq $lastImageOfPreviousSet);		
		$lastImageOfPreviousSet = $lastFile->{file};
		my $flag = $firstFileInPrevSet ? "*" : "";
		$repeatCount++ if $firstFileInPrevSet; 

		for my $image (@{$set->{images}}) {

			my $file = $image->{file};

			# todo: copy image

			delete $fileHash{$file};
		}

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

my @remainingFiles = keys %fileHash;
my $remainingFileCount = scalar @remainingFiles;

	if ($remainingFileCount) {
		print <<END;
UNUSED FILES:	$remainingFileCount
DIRECTORY:	$UNUSED_FILE_DIR

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

