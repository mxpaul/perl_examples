#!/usr/bin/env perl
use strict;
use warnings;

open(my $f, '<', $ARGV[0]) or die sprintf("open [%s] error: %s", $ARGV[0], $!);
my @lines = <$f>;
close($f);
my @words = map {split /\s+/} @lines;
printf("%8d %8d\n", scalar(@lines), scalar(@words));
