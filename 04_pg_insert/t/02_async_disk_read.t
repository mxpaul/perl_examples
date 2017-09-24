#!/usr/bin/env perl
use strict; use warnings;
use FindBin qw($Bin); use lib ("$Bin/../lib", "$Bin/lib");
use Test::More;
use Test::Deep;
use Data::Dumper;
use Carp;
use Test::AE; #cvt

use File::Path qw(rmtree);
use File::Temp qw(tempdir);

use Pg::Import::Reader;

my $reader = Pg::Import::Reader->new(
	file_name        => '/some/file',
	read_limit_bytes => 10,
);

is($reader->{file_name}, '/some/file', 'file_name remembered');
is($reader->{read_limit_bytes}, 10, 'read_limit_bytes remembered');

sub SetUp {
	my %state = (
		basedir  => tempdir,
	);
	$state{testdata} = <<_END;
4	Title 4	http://banner4.host.name/cgi-bin/click.php?id=4&source=banner
5	Title 5	http://banner5.host.name/cgi-bin/click.php?id=5&source=banner

# coment
_END
	chomp($state{testdata});
	$state{test_file} = join('/', $state{basedir}, 'test.txt');

	open(my $f, '>', $state{test_file}) or croak "open: $state{test_file}: $!";
	print $f $state{testdata};

	return \%state;
}

sub TearDown {
	my $state = shift or croak "Need state";
	rmtree $state->{basedir} if $state->{basedir} && -d $state->{basedir};
}

{ # test line by line file read
	my $state = SetUp;
	my $content = '';
	my $r; $r = Pg::Import::Reader->new(
		file_name        => $state->{test_file},
		read_limit_bytes => 10,
		cb_matched_line  => sub {
			return unless $r;
			while(my $match = $r->pop_line()) {
				$content .= $match->{line};
			}
			$r->read_more;
		},
		cb_nonmatch_line => sub {fail "unumatched line for default contents"},
		cb_error         => sub {BAIL_OUT("reader error: " . $_[0])},
		cb_eof           => my $cv = AE::cvt(10),
	);
	$r->read_more;
	eval{$cv->recv}; fail("cvt fail: $@") if $@;
	is($content, $state->{testdata}, 'reader content matches original content');
	TearDown($state);
}

{ # test matching groups extract
	my $state = SetUp;
	my @want_records = (
		{id => 4, title => 'Title 4', link => 'http://banner4.host.name/cgi-bin/click.php?id=4&source=banner'},
		{id => 5, title => 'Title 5', link => 'http://banner5.host.name/cgi-bin/click.php?id=5&source=banner'},
	);
	my @records;
	my $r; $r = Pg::Import::Reader->new(
		file_name        => $state->{test_file},
		read_limit_bytes => 3,
		#queue_limit      => 1,
		valid_line_re    => qr/(\d+)\t+([^\t]+)\t+([^\t\n]+)/,
		cb_matched_line  => sub {
			return unless $r;
			while(my $match = $r->pop_line()) {
				push @records, {map {($_ => shift @{$match->{match}})} qw(id title link)}
			}
			$r->read_more;
		},
		cb_nonmatch_line => sub {fail "unumatched line for default contents"},
		cb_error         => sub {BAIL_OUT("reader error: " . $_[0])},
		cb_eof           => my $cv = AE::cvt(10),
	);
	$r->read_more;
	eval{$cv->recv}; fail("cvt fail: $@") if $@;
	#warn Dumper \@records;
	cmp_deeply(\@records, \@want_records, 'found records provided by test input') or diag Dumper \@records;
	TearDown($state);
}

done_testing;

__DATA__
3	Mr Title	http://banner1.host.name/cgi-bin/click.php?id=3&source=banner

