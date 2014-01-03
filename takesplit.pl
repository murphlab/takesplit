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

my @inFiles = (<$inputDir/*>);
my $inFileCount = scalar @inFiles;

#print "Read $inFileCount inFiles\n";

my @imageData;

my $subSecAvailable = 1; 

for my $inFile (@inFiles) {
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
	if (!($dateTimeOrig or $subSecDateTimeOrig)) {
		die "Neither DateTimeOriginal or SubSecDateTimeOriginal EXIF tags found. Exiting";
	}
	if (!$subSecDateTimeOrig) {
		$subSecAvailable = 0;	
	}
	my $epoch = dateTimeToEpoch($dateTimeOrig);
	my $subSecEpoch = dateTimeToEpoch($subSecDateTimeOrig);
	push @imageData, $exif;
}

print "subSecAvailable: $subSecAvailable\n";

sub dateTimeToEpoch
{
	# eg: 2013:12:31 22:32:42
	my $dateTime = shift;
	my ($date,$time) = split /\s/, $dateTime;
	my ($year, $month, $day) = split /:/, $date;
	my ($hour, $minute, $second) = split /:/, $time;
	#print "dateTime: $dateTime\n";
	print "year: $year month: $month day: $day hour: $hour minute: $minute second: $second\n";
	my $epoch = timelocal(0,$minute,$hour,$day,$month-1,$year) + $second;
	return $epoch;
}

