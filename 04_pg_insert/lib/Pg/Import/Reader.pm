package Pg::Import::Reader;
use Mouse;
use v5.10;

has file_name        => (is => 'rw', );
#has queue_limit      => (is => 'rw', default => 10);
has read_limit_bytes => (is => 'rw', default => (1<<17));
has valid_line_re    => (is => 'rw', default => sub{qr/.*?/});
has cb_matched_line  => (is => 'rw');
has cb_eof           => (is => 'rw');
has cb_error         => (is => 'rw');
has eof              => (is=>'rw', default => 0);
has _buf             => (is=>'rw', default => '');
has _in_read         => (is=>'rw', default => 0);
has _queue           => (is=>'rw', default => sub{ [] });
has async_open       => (is=>'rw', default => sub{ \&aio_open });
has async_read       => (is=>'rw', default => sub{ \&aio_read });

use Carp;
use Data::Dumper;
use AnyEvent::AIO;
use IO::AIO;
use Test::More;

sub finished { my $self = shift;
	$self->{eof} && length($self->{_buf}) == 0 && scalar @{$self->{_queue}} == 0;
}

sub pop_line { my $self = shift;
	return shift @{$self->{_queue}};
}

sub read_more { my $self = shift;
	return if $self->{_in_read} or $self->{eof};
	$self->{_in_read} = 1;
	$self->read_fh(sub {
		my $res = shift;
		if ($res->{error}) {
			$self->{_in_read} = 0;
			$self->{cb_error}->($res->reason) if $self->{cb_error};
		} else {
			my $cnt = $self->process_input;
			$self->{_in_read} = 0;
			$self->{cb_matched_line}->($cnt) if $self->{cb_matched_line} && $cnt > 0;
			if ($self->{eof}) {
				$self->{cb_eof}->() if $self->{cb_eof};
			} else {
				$self->read_more unless $cnt > 0;
			}
		}
	});
}

sub read_fh { my $self = shift;
	my $cb = pop or croak 'need cb';
	unless ($self->{fh}) {
		$self->{async_open}->($self->{file_name}, IO::AIO::O_RDONLY, 0, sub {
			if ($self->{fh} = shift) {
				$self->read_fh($cb);
			} else {
				$cb->({error=>1, reason => "async_open: $!"});
			}
		});
		return;
	}
	$self->{async_read}->(
		$self->{fh},
		undef,
		$self->{read_limit_bytes},
		$self->{_buf},
		length($self->{_buf}),
		sub{
			my $len = shift;
			if (!defined $len) {
				$cb->({error =>1, reason => "async_read $!"});
			} elsif ($len == 0) {
				$self->{eof} = 1;
				$cb->({error =>0});
			} else {
				$cb->({error =>0});
			}
		}
	);

}

sub process_input { my $self = shift;
	my $line_cnt = 0;
	while (1) {
		if (
			(!$self->{eof} && $self->{_buf} =~ /\G^$self->{valid_line_re}\n/gcm) ||
			($self->{eof} && $self->{_buf} =~ /\G^$self->{valid_line_re}\n?\z/gcm)
		) {
			$line_cnt++;
			my $line = substr($self->{_buf}, $-[0], $+[0]-$-[0]);
			my $matches = [map {substr($self->{_buf}, $-[$_], $+[$_]-$-[$_])} 1..$#{-}];
			push @{$self->{_queue}}, {line => $line, match => $matches};
		} elsif ($self->{_buf} =~ /\G^(.+?)\n/gcm) {
			#diag "NON MATCH line";
		} else {
			last;
		}
	}
	substr($self->{_buf}, 0, pos($self->{_buf})//0, '');
	return $line_cnt;
}

__PACKAGE__->meta->make_immutable;
1;

