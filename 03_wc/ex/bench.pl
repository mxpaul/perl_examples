#!/usr/bin/env perl
use strict;
use warnings;

use FindBin qw($Bin); use lib ("$Bin/../lib");

use Carp qw(croak);
use Benchmark qw(cmpthese :hireswallclock);

use Word::Count;

sub compare_for_input {
	my $funcs = shift or croak 'need function names';
	my $cases = shift; croak "need cases array" unless ref $cases eq 'ARRAY';
	for my $case (@$cases) {
		croak "need cases to be a HASH" unless ref $case eq 'HASH';
		croak 'need desc key for case' unless exists $case->{desc};
		croak 'need input array for case '. $case->{desc} unless ref $case->{input} eq 'ARRAY';
		printf("Benchmark functions(%s) for case %s\n", join(' ',@$funcs), $case->{desc});
		cmpthese(-5, { map { my $funcname = $_;  $funcname => sub {
			open my $f, '<', \$case->{input}[0] or croak "open input fd: $!";
			no strict 'refs';
			my $got =  &$funcname($f);
			close($f);
		}} @$funcs });
	}
}

my @cases = (
	{ desc  => 'few lines, few words',
		input => ["Just another perl hacker\n"x3],
	},
	{ desc  => 'many lines of few words',
		input => ["Just another perl hacker\n"x1e6],
	},
	{ desc  => 'only newlines',
		input => ["\n"x1e6],
	},
	{ desc  => 'one long word',
		input => ["w"x1e6],
	},
	{ desc  => '12 lines, long words',
		input => [join("\n", map{join("\t \t", "$_"x1e6, "$_"x1e6)} qw(c r t y j p))],
	},
);
compare_for_input([qw(wc_from_fd wc_from_fd_single_pass)], \@cases);
