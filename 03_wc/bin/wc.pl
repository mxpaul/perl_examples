#!/usr/bin/env perl
use strict;
use warnings;

use FindBin qw($Bin);
use lib ("$Bin/../lib");
use Word::Count qw(wc_from_fd);

use feature 'say';
my $fname = $ARGV[0] or die 'Need file name as first arg';
die "File $fname not exists" unless -e $fname;
die "File $fname is not a file" unless -f $fname;
die "File $fname is not readable" unless -r $fname;

open my $f, '<', $fname or die "open $fname error: $!";
my $res = wc_from_fd($f);
close $f;

if ($res->{error}) {
	warn "error counting words and lines: " . $res->{error};
} else {
	printf("Lines: %8d Words: %8d\n", $res->{lines}, $res->{words});
}
