takesplit
=========

Perl script for organizing a bunch of image files into time-lapse "takes."

This requires the Perl ExifTool module:
http://www.sno.phy.queensu.ca/~phil/exiftool/

```
NAME
	takesplit.pl -- Organize a bunch of image files into time-lapse "takes."

SYNOPSIS 
	takesplit.pl -i <input_dir> [-o <output_dir>] [-r] [-m <min_frames>] 

DESCRIPTION
	This script is useful for organizing a bunch of images (say, on one card),
	that contain multiple time-lapse sequences. It examines the time intervals
	between them and makes its best guess as to how they should be grouped.
	There may be ambiguous situtations where it's not obvious which image
	belongs to which sequence, in which case it will copy the same image
	to both sequences.

	A subdirectory of the specificed output_dir is created for each take,
	and the images for that take are *copied* to it. Any images not used
	in any of the takes are copied to the "noset" subdirectory.

	A summary of the analysis and resulting directory structure is written
	to STDOUT. It would probably be useful to redirect this output to a 
	file.

	The options are as follows:

	-i <input_dir>	
		Directory containing image files to be grouped.

	-o <output_dir>
		Directory to write grouped files to. Required unless -r flag is used.

	-r	Report only. Produces summary of analysis without copying any files.

	-m <min_frames>
		Minimun number of frames required for a sequence. Default is 3.

	An example usage is:

	takesplit.pl -i /Volumes/CARD1 -o ~/Photos/2014-01-05-TLShoot > ~/Photos/2014-01-05-TLShoot/summary.txt
```

Here is an example of the report output:

```
Infile count:   1171

Set count:      7

Directory: 	2013-12-23-14-38-55
File count:	101
Starts:		2013:12:23 14:38:55
Ends:		2013:12:23 14:47:14
Interval avg:	4.99
First file:	input//IMG_8889.CR2 
Last file:	input//IMG_8989.CR2

Directory: 	2013-12-23-14-47-26
File count:	360
Starts:		2013:12:23 14:47:26
Ends:		2013:12:23 15:17:20
Interval avg:	4.99721448467967
First file:	input//IMG_8990.CR2 
Last file:	input//IMG_9349.CR2

Directory: 	2013-12-23-15-17-29
File count:	251
Starts:		2013:12:23 15:17:29
Ends:		2013:12:23 15:38:18
Interval avg:	4.996
First file:	input//IMG_9350.CR2 
Last file:	input//IMG_9600.CR2

Directory: 	2013-12-23-15-44-49
File count:	26
Starts:		2013:12:23 15:44:49
Ends:		2013:12:23 15:46:55
Interval avg:	5.04
First file:	input//IMG_9606.CR2 
Last file:	input//IMG_9631.CR2

Directory: 	2013-12-23-15-51-14
File count:	243
Starts:		2013:12:23 15:51:14
Ends:		2013:12:23 16:11:24
Interval avg:	5
First file:	input//IMG_9663.CR2 
Last file:	input//IMG_9905.CR2

Directory: 	2013-12-23-16-21-27
File count:	5
Starts:		2013:12:23 16:21:27
Ends:		2013:12:23 16:21:47
Interval avg:	5
First file:	input//IMG_9914.CR2 
Last file:	input//IMG_9918.CR2

Directory: 	2013-12-23-16-22-02
File count:	182
Starts:		2013:12:23 16:22:02
Ends:		2013:12:23 16:37:06
Interval avg:	4.99444444444444
First file:	input//IMG_9919.CR2 
Last file:	input//IMG_0101.CR2

Unusued files:	3
Directory:	noset
```
