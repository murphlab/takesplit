takesplit
=========

Tool for organizing a bunch of files into time-lapse "takes."

```
NAME
	takesplit.pl -- Organize a bunch of image files into time-lapse "takes."

SYNOPSIS 
	takesplit.pl -i <input_dir> [-o <output_dir>] [-r] [-m <min_frames>] 

DESCRIPTION
	This script is useful for organizing a bunch of images (say, on one card),
	that contain multiple time-lapse sequences. It examins the intervals
	between them and makes it's best guess as to how they should be grouped.
	There may be ambiguous situtations where it's not obvious which image
	belongs to which sequence, in which case it will copy the same image
	to both sequences.

	A subdirectory of the specificed output_dir is created for each take,
	and the images for that take are *copied* to it. Any images not used
	in any of the takes are copied to the "noset" subdirectory.

	A summary of the analysis and resulting directory structure is written
	to STDERR. It would probably be useful to redirect this output to a 
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
