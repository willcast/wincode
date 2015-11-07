WinCode audio transcoder
========================

Dependencies
------------

This program runs Nero AAC encoder, decoder and tagger, which are assumed to be in /usr/local/bin. If that is not the case, then change the line referring to that path in the source.

Basic usage
-----------
To make a new music folder:
    wincode-auto.pl <indir> <outdir> <target_size> <nthreads>

To update (add to) an existing music folder:
    wincode-auto.pl <indir> <outdir> -<target_br> <nthreads>
Note the '-' before the target bit rate.


 * *indir* is the location of the existing music library. Its layout will be duplicated in the destination. Only music files and directories will be replicated.
 * *outdir* is the path to the root of the new music library. The last component of the path will be created if it doesn't already exist, but its parents must be present.
* *target_size* is the amount of storage space that you want the new music library to take when the inital transcode job completes.
* *target_br* is the average bitrate used when transcoding every song. You will have to use this after the initial job. You can also create a new library with this syntax if you know the bit rate you want already.
* *nthreads* is the number of decode/encode/tag jobs to run in parallel. This program typically works best if you use exactly the number of physical threads here.
