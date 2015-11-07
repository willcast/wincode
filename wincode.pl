#!/usr/bin/perl
use warnings;

my @mediaexts = qw(.mp3 .ogg .flac .wav .aac .m4a);
my $NEROPATH = "/usr/local/bin";

my @inlist;			# media to convert
my @outlist; 			# destinations for conversion
my @dirlist; 			# directories to create
my @filelist;			# files to copy
my $nthreads;			# number of threads to run at once

my $target_size;
my $target_size_raw = 0;

my $reserved_space = 0.2;

my $bitrate;			# bit rate of output

my $ttime = 1, $ptime = 0, $rtime = 0;
my $nf = 1, $pf = 0, $rf = 0;
my $tisize = 1, $pisize = 0, $risize = 0;
my $osize = 0;
my $twall = 1, $ewall = 0, $rwall = 0;
my $cf = "";

my $stwall = time;

my $curfile;
if (scalar(@ARGV) < 4) {
	print "\n";
	print "Win-Code 1.0: Usage:\n";
	print "To make a new music folder: \n";
	print "wincode-auto.pl <indir> <outdir> <target_size> <nthreads>\n";
	print "\n"; 
	print "To add to an existing music folder:\n";
	print "wincode-auto.pl <indir> <outdir> -<target_br> <nthreads>\n";
	print "\n";
	exit 1;
}

my $clear = `clear`;

# Process command line parameters.
$indir = $ARGV[0];
chop($indir) if ($indir =~ /\/$/);
$indir .= "/";

$outdir = $ARGV[1];
chop($outdir) if ($outdir =~ /\/$/);
$outdir .= "/";

$target_size = $ARGV[2];

$nthreads = $ARGV[3];

# Determine raw target size.
if ($target_size =~ /^\-([0-9]+)B/) { $target_br = $1; }
elsif ($target_size =~ /^\-([0-9]+)k/i) { $target_br = $1 * 1024; }
elsif ($target_size =~ /^([0-9]+)B/) { $target_size_raw = $1; $target_br = 0; }
elsif ($target_size =~ /^([0-9]+)k/i) { $target_size_raw = $1 * 1024; $target_br = 0; } 
elsif ($target_size =~ /^([0-9]+)m/i) { $target_size_raw = $1 * 1048576; $target_br = 0; } 
elsif ($target_size =~ /^([0-9]+)g/i) { $target_size_raw = $1 * 1073741824; $target_br = 0; }
else { die 'Invalid format for target size.'; }

print "target: $target_size\n";
print "threads: $nthreads\n";
sleep .1;

chdir $indir;
traverse("");

$nf = scalar(@inlist);

update_screen();

get_total();

if ($target_br != 0) {
	$bitrate = $target_br;
} else {
	$bitrate = int($target_size_raw / $ttime * 8 * (1 - $reserved_space));
} 
my $sbitrate = str_size($bitrate);
my $ssize = str_size($bitrate * $ttime / 8);
print "size will be $ssize\n";
print "bitrate will be $sbitrate ps\n";
print "continue? (y/n): ";

$confirm = <STDIN>;
die "user aborted the conversion" unless ($confirm =~ /^y/i);

# Create destination dirs.
mkdir $outdir;
foreach (@dirlist) { mkdir; }
		
my $nchildren = 0;

for ($i = 0; $i < scalar(@inlist); ++$i) {
	$cf = descape($inlist[$i]);
	my $outfile = descape($outlist[$i]);
	my $rawtagfile = $outlist[$i] . ".tag";
	my $tagfile = descape($rawtagfile);

	$pisize += get_size($cf);

	update_screen();

	++$nchildren;
	my $pid = fork;
	die "couldn't fork: $!\n" unless defined($pid);
	if ($pid == 0) {
		my $ctagfh;
		my $retval = 0;

		my $tcmd = "ffmpeg -i ";
		$tcmd .= $cf;
		$tcmd .= " -acodec pcm_s16le -ac 2 -ar 44100 -f wav - 2>";
		$tcmd .= $tagfile;
		$tcmd .= " | $NEROPATH/neroAacEnc -if - -br $bitrate";
		$tcmd .= " -ignorelength -of ";
		$tcmd .= $outfile;	
		$tcmd .= " 2>&1 >/dev/null";

		$retval = system($tcmd);
		system("du -b " . $outfile . " >> " . $tagfile);

		if (open($ctagfh, $rawtagfile)) {
			foreach (<$ctagfh>) {
			        if (/track[ ]+\: ([0-9]+)\/[0-9]+/) { system "$NEROPATH/neroAacTag " . $outfile . " -meta:track=\"$1\" 2>&1 >/dev/null"; }
				if (/title[ ]+\: (.+)$/) { system "$NEROPATH/neroAacTag \"$outfile\" -meta:title=\"$1\" 2>&1 >/dev/null"; }
				if (/artist[ ]+\: (.+)$/) { system "$NEROPATH/neroAacTag " . $outfile . " -meta:artist=\"$1\" 2>&1 >/dev/null "; }
				if (/album[ ]+\: (.+)$/) { system "$NEROPATH/neroAacTag " . $outfile . " -meta:album=\"$1\" 2>&1  >/dev/null"; }
				if (/genre[ ]+\: (.+)$/) { 
					system "$NEROPATH/neroAacTag " . $outfile . " -meta:genre=\"$1\" 2>&1 >/dev/null"; 
					last; 
				}
			}
			close $ctagfh;
		} else {	
			warn "Tagfile not created: $rawtagfile";
		}
		exit($retval);
	}

	$tagfiles{$pid} = $rawtagfile;

	if ($nchildren >= $nthreads) { 
		my $ptagfh;
		my $deadpid = wait;
		--$nchildren;
		++$pf;

		if (open($ptagfh, $tagfiles{$deadpid})) {
			foreach (<$ptagfh>) {
					if (/Duration\: ([0-9][0-9])\:([0-9][0-9])\:([0-9][0-9])\.([0-9][0-9])\,/) {
						$ptime += (($1 * 60) + $2) * 60 + $3 + ($4 / 100);
					}
					if (/^([0-9]+)/) { $osize += $1; }
			}
			close $ptagfh;
			unlink $tagfiles{$deadpid};
		}
	}
}

print "waiting on children...";
while ($nchildren) {
	wait;
	--$nchildren;
	++$pf;
	if (open($ptagfh, $tagfiles{$deadpid})) {
		foreach (<$ptagfh>) {
				if (/Duration\: ([0-9][0-9])\:([0-9][0-9])\:([0-9][0-9])\.([0-9][0-9])\,/) {
					$ptime += (($1 * 60) + $2) * 60 + $3 + ($4 / 100);
				}
				if (/^([0-9]+)/) { $osize += $1; }
		}
		close $ptagfh;
		unlink $tagfiles{$deadpid};
	}
}

print "done!\n";

sub traverse {
	my $subdir = $_[0];
	my $newdir = "$outdir/$subdir";
	push(@dirlist, $newdir);
	$subdir = "." unless $subdir;
	opendir(my $dh, $subdir) || die "can't opendir $subdir: $!";
	while (readdir $dh) {
		my $scanpath = $subdir . '/' .  $_;
		next if /^\./;
		traverse($scanpath) if (-d $scanpath);
		foreach (@mediaexts) {
			if ($scanpath =~ /$_$/i) {
				my $extlen = length($_);
				my $basepath = substr($scanpath, 0, -$extlen);	
				my $outfile = $outdir . $basepath . ".m4a";
				my $oldfile = $outdir . $scanpath . ".m4a";
				if (-e $oldfile) {
					print("renamed a double extension file.\n");
					print("oldfile = $oldfile\n");
					print("outfile = $outfile\n");
					rename($oldfile, $outfile);
				}
				unless (-e $outfile) {			
					push(@inlist, "$indir/$scanpath");
					push(@outlist, $outfile);
				}
			} else {
				push(@filelist, $scanpath);
			}
		}
	}
	closedir $dh;
}	

sub descape {
	return $_[0] if $_[0] =~ /^[a-zA-Z0-9_\-]+\z/;
	my $s = $_[0];
	$s =~ s/'/'\\''/g;
	return "'$s'";
}
	
sub get_total {
	$ttime = 0;
	$tisize = 0;
	foreach (@inlist) {
		++$i;
		$ttime += get_len($_);
		$tisize += get_size($_);
		update_screen()	unless ($i % int($nf));
	}
}

sub get_len {
	my $ret = 0;
	my $fname = descape($_[0]);
	my @ffout = qx( avconv -i $fname 2>&1 );
	foreach (@ffout) {
		if (/Duration\: ([0-9][0-9])\:([0-9][0-9])\:([0-9][0-9])\.([0-9][0-9])\,/) {
			$ret = (($1 * 60) + $2) * 60 + $3 + ($4 / 100);
			last;		
		}
	}
	return $ret;
}

sub get_size {
	my $in = descape($_[0]);
	my $du = qx( du -b $in );
	$du =~ /^([0-9]+)/;
	return $1;
}

sub str_time {
	my $in = $_[0];
	my $s = $in % 60;
	my $m = int($in / 60) % 60;
	my $h = int($in / 3600);
	return "$h:$m:$s";
}

sub str_size {
	my $b = $_[0];
	my $k = int($b / 1024);
	my $m = int($k / 1024);
	my $g = int($m / 1024);
	return "$g GiB" if ($g >= 10);
	return "$m MiB" if ($m >= 10);
	return "$k kiB" if ($k >= 10);
	return "$b B";
}	

sub update_screen {
	my $rate;
	my $percent;
	$rtime = $ttime - $ptime;
	$rf = $nf - $pf;
	$risize = $tisize - $pisize;

	$ewall = time - $stwall;
	if ($ttime > .001) {
		$percent = int($ptime / $ttime * 100);
	} else {
		$percent = 0;
	}
	if ($ewall > .001) {
		$rate = $ptime / $ewall;
	} else {
		$rate = 0;
	}
	if ($rate) { 
		$twall = $ttime / $rate;
		$rwall = $twall - $ewall;
 	} else { 
		$twall = 0;
		$rwall = 0;
	}
	$rate = int($rate);
 

	my $sttime = str_time($ttime); my $sptime = str_time($ptime); my $srtime = str_time($rtime);
	my $stwall = str_time($twall); my $sewall = str_time($ewall); my $srwall = str_time($rwall);
	my $stisize = str_size($tisize); my $spisize = str_size($pisize); my $srisize = str_size($risize);
	my $sosize = str_size($osize);

	print $clear;
	print "duration: $sttime total, $sptime processed, $srtime remaining\n";
	print "files: $nf total, $pf processed, $rf remaining\n";
	print "input data: $stisize total, $spisize processed, $srisize remaining\n";
	print "output data: $sosize processed, percent complete: $percent%, rate: $rate X\n";
	print "current file: $cf\n";
	print "\n";
	print "wall time: $stwall estimated total, $sewall elapsed, $srwall ETA\n";
	print "\n";
}
