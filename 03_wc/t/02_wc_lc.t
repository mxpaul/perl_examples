#!/usr/bin/env perl
use strict;
use warnings;

use FindBin qw($Bin); use lib ("$Bin/../lib");

use Test::More;
use Test::Deep;
use Carp qw(croak);
use Data::Dumper;

use Word::Count;

sub table_tests_run {
	my $funcname = shift or croak 'need function name';
	my $cases = shift; croak "need cases array" unless ref $cases eq 'ARRAY';
	for my $case (@$cases) {
		croak "need cases to be a HASH" unless ref $case eq 'HASH';
		croak 'need desc key for case' unless exists $case->{desc};
		croak 'need input array for case '. $case->{desc} unless ref $case->{input} eq 'ARRAY';
		croak 'need want hash' unless ref $case->{want} eq 'HASH';
		my $desc = sprintf('%s when %s', $funcname, $case->{desc});
		open my $f, '<', \$case->{input}[0] or croak "open input fd: $!";
		my $got = do {no strict 'refs'; &$funcname($f)};
		close($f);
		cmp_deeply($got, $case->{want}, $desc) or diag Dumper $got;
	}
}

my @cases = (
	{ desc => 'empty input',
		input => [""],
		want => {error => 0, lines => 0, words => 0,},
	},
	{ desc => 'single space',
		input => [" "],
		want => {error => 0, lines => 1, words => 0,},
	},
	{ desc => 'single space + newline',
		input => [" \n"],
		want => {error => 0, lines => 1, words => 0,},
	},
	{ desc => 'space + newline + space',
		input => [" \n "],
		want => {error => 0, lines => 2, words => 0,},
	},
	{ desc => '1 line, one word',
		input => ["line"],
		want => {error => 0, lines => 1, words => 1,},
	},
	{ desc => '1 line, three words',
		input => ["line and word"],
		want => {error => 0, lines => 1, words => 3,},
	},
	{ desc => '2 line, three words',
		input => ["line \nnew word"],
		want => {error => 0, lines => 2, words => 3,},
	},
	{ desc => '2 line, three words, newline at end',
		input => ["line \nnew word\n"],
		want => {error => 0, lines => 2, words => 3,},
	},
	{ desc => '2 line, three words, newline at end, leading multiple spaces and tab',
		input => ["line \n  	new word\n"],
		want => {error => 0, lines => 2, words => 3,},
	},
	{ desc => 'four lines, only last has word',
		input => ["\n\n\nword\n"],
		want => {error => 0, lines => 4, words => 1,},
	},
	{ desc => 'four lines, only last has word, no final newline',
		input => ["\n\n\nword"],
		want => {error => 0, lines => 4, words => 1,},
	},
	{ desc => 'longer lines, longer words',
		input => [join("\n", map{join("\t \t", "$_"x1e6, "$_"x1e6)} qw(c r t y j p))],
		want => {error => 0, lines => 6, words => 12,},
	},
);
table_tests_run('ethalon_wc_from_fd',\@cases);
table_tests_run('wc_from_fd',\@cases);
table_tests_run('wc_from_fd_single_pass_slow',\@cases);

done_testing;
