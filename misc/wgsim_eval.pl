#!/usr/bin/perl -w

# Contact: lh3
# Version: 0.1.3

use strict;
use warnings;
use Getopt::Std;

&wgsim_eval;
exit;

sub wgsim_eval {
  my %opts;
  getopts('pc', \%opts);
  die("Usage: wgsim_eval.pl [-pc] <in.sam>\n") if (@ARGV == 0 && -t STDIN);
  my (@c0, @c1);
  my ($max_q, $flag) = (0, 0);
  my $gap = 5;
  $flag |= 1 if (defined $opts{p});
  $flag |= 2 if (defined $opts{c});
  while (<>) {
	my @t = split;
	my $line = $_;
	my ($q, $is_correct, $chr, $left, $rght) = (int($t[4]/10), 1, $t[2], $t[3], $t[3]);
	$max_q = $q if ($q > $max_q);
	# right coordinate
	$_ = $t[5]; s/(\d+)[MDN]/$rght+=$1,'x'/eg;
	--$rght;
	# correct for soft clipping
	$left -= $1 if (/^(\d+)S/);
	$rght += $1 if (/(\d+)S$/);
	# skip unmapped reads
	next if (($t[1]&0x4) || $chr eq '*');
	# parse read name and check
	++$c0[$q];
	if ($t[0] =~ /^(\S+)_(\d+)_(\d+)_/) {
	  if ($1 ne $chr) { # different chr
		$is_correct = 0;
	  } else {
		if ($flag & 2) {
		  if (($t[1]&0x40) && !($t[1]&0x10)) { # F3, forward
			$is_correct = 0 if (abs($2 - $left) > $gap);
		  } elsif (($t[1]&0x40) && ($t[1]&0x10)) { # F3, reverse
			$is_correct = 0 if (abs($3 - $rght) > $gap);
		  } elsif (($t[1]&0x80) && !($t[1]&0x10)) { # R3, forward
			$is_correct = 0 if (abs($3 - $left) > $gap);
		  } else { # R3, reverse
			$is_correct = 0 if (abs($2 - $rght) > $gap);
		  }
		} else {
		  if ($t[1] & 0x10) { # reverse
			$is_correct = 0 if (abs($3 - $rght) > $gap); # in case of indels that are close to the end of a reads
		  } else {
			$is_correct = 0 if (abs($2 - $left) > $gap);
		  }
		}
	  }
	} else {
	  die("[wgsim_eval] read '$t[0]' was not generated by wgsim?\n");
	}
	++$c1[$q] unless ($is_correct);
	print STDERR $line if (($flag&1) && !$is_correct && $q > 0);
  }
  # print
  my ($cc0, $cc1) = (0, 0);
  for (my $i = $max_q; $i >= 0; --$i) {
	$c0[$i] = 0 unless (defined $c0[$i]);
	$c1[$i] = 0 unless (defined $c1[$i]);
	$cc0 += $c0[$i]; $cc1 += $c1[$i];
	printf("%.2dx %12d / %-12d  %12d  %.3e\n", $i, $c1[$i], $c0[$i], $cc0, $cc1/$cc0);
  }
}