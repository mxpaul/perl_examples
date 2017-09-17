#!/usr/bin/env perl
open F, $ARGV[0] || die $!;
my @lines = <F>;
my @words = map {split /\s/} @lines;
printf "%8d %8d\n", scalar(@lines), scalar(@words); close(F);
