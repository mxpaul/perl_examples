#!/usr/bin/env perl
use strict;
use warnings;

use FindBin qw($Bin); use lib ("$Bin/../lib");

use Pg::Import::Reader;
use AnyEvent::PostgreSQL;
use EV;
use Data::Dumper;

my $fname = $ARGV[0] or die 'need file name as first argument';
my $conn_info = {
	host     => '127.0.0.1',
	dbname   => 'pginserter',
	user     => 'pginserter',
	password => '1etmein!',
};

my $work;
my $reader; $reader = Pg::Import::Reader->new(
	file_name        => $fname,
	#read_limit_bytes => 10,
	queue_limit      => 2,
	valid_line_re    => qr/(\d{1,30})\t([^\t]{0,200})\t([^\t\n]{1,4000})/,
	cb_error  => sub {
		my $err = shift;
		warn sprintf("[ERR] Reader error: %s", $err->{reason});
		EV::unloop if $err->{fatal};
	},
	cb_eof => sub {
		goto &$work;
	},
);

my $pg_ready = 0;
my $cf_reported = 0;
my $pg; $pg = AnyEvent::PostgreSQL->new(
		pool_size         => 10,
		conn_info         => $conn_info,
		request_timeout   => 3,
		#on_connect_first  => sub {
		on_connect_last  => sub {
			my $desc = shift;
			warn "Connected: $desc\n";
			$pg_ready = 1; $cf_reported = 0;
			goto &$work;
		},
		on_disconnect_last => sub {
			$pg_ready = 0; $cf_reported = 0;
		},
		on_connfail => sub {
			$pg_ready = 0;
			my $res = shift;
			warn sprintf('[ERR] connfail: %s', $res->{reason}) unless $cf_reported++;
		},
);

my $query_cnt = 0;
$reader->{cb_matched_line} = $work = sub {
	return unless $pg_ready;
	while ($query_cnt < $pg->{pool_size} && (my $m = $reader->pop_line)) {
		$query_cnt ++;
		$pg->push_query(
			['INSERT INTO banners (banner_id, title, url) VALUES($1, $2, $3)', @{$m->{match}}],
			sub {
				$query_cnt --;
				my $res = shift;
				if ($res->{error}) {
					$m->{fail_cnt}++;
					my $will_desc;
					if ($m->{fail_cnt} >= 2 || $res->{fatal}) {
						$will_desc = "giving up after $m->{fail_cnt} tries";
					} else {
						$will_desc = 'will retry';
						$reader->push_line($m);
					}
					warn sprintf("insert: [%s][%s][%s]: error: %s, %s\n", @{$m->{match}}, $res->{reason}, $will_desc);
				} else {
					warn sprintf("insert: [%s][%s][%s]: OK\n", @{$m->{match}});
				}
				goto &$work;
			}
		);
	}
	if ($reader->finished && $query_cnt == 0) {
		warn "DONE\n";
		EV::unloop;
		return;
	}
	$reader->read_more;
};

$pg->connect;
EV::loop;

