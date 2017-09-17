#!/usr/bin/env perl
use strict;
use warnings;
use v5.10;

use DBI;
use DBD::Pg;
use Carp;
use Data::Dumper;

my %opt = (
	pg_dsn => 'dbi:Pg:host=127.0.0.1;dbname=pginserter',
	pg_user => 'pginserter',
	pg_pass => '1etmein!',
	tbl_banners => 'banners',
);

sub insert_row {
	my $dbh = shift or croak 'need dbh';;
	my $row = shift or croak 'need row';
	my $opt = pop;
	my $table_name = ref $opt eq 'HASH' ? $opt->{tbl_banners}//'banners' : 'banners';
	state $sth = $dbh->prepare(sprintf('INSERT INTO %s (banner_id, title, url) VALUES(?, ?, ?)',
		$dbh->quote_identifier($table_name)
	));
	$sth->execute(@{$row}{qw(banner_id title url)});
}


sub create_db_connector {
	my $opt = shift or croak 'need opt hash';
	my $dbh = DBI->connect(@{$opt}{qw(pg_dsn pg_user pg_pass)},
		{RaiseError => 1, AutoCommit => 1, PrintError => 0});
	return $dbh;
}

my $fname = $ARGV[0] or die "Usage: $0 </file/to/import/into/postgres>\n";
open(my $fh, '<', $fname) or die "open $fname: $!";
my $dbh = create_db_connector(\%opt) or croak "create_db_connector failed";
while (<$fh>) { chomp;
	next if /^(?:#|$)/;
	unless (/^([^\t]{1,30})\t([^\t]{0,200})\t(.{1,4000})$/) {
		warn "Can't parse line: " . $_ . "\n";
		next;
	}
	my $row = {banner_id => $1, title => $2, url => $3};
	eval {insert_row($dbh, $row, \%opt)};
	warn "[ERR] insert: $_: $@" if $@;
}

close $fh;
