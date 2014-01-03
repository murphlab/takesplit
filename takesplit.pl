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
