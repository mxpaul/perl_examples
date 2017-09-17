package Word::Count;

our $VERSION = v0.01;

use parent qw(Exporter);
our @EXPORT = our @EXPORT_OK = qw(wc_from_fd ethalon_wc_from_fd wc_from_fd_single_pass_slow);

use Carp;
use Data::Dumper;

sub wc_from_fd {
	my $fh  = shift or croak 'need fh';
	my ($lc, $wc) = (0, 0);
	while(<$fh>) {
		$lc++;
		$wc += 0 + grep {length $_} split /\s+/;
	}
	return {error => 0, lines => $lc, words => $wc};
}

sub wc_from_fd_single_pass_slow {
	my $fh  = shift or croak 'need fh';
	my $res = {error => 0};
	my ($wc, $lc) = (0, 0);

	my ($buf, $pos, $maxread) = ('',0, 1e8);
	my ($in_word, $has_line) = (0, 0);
	my ($re_newline, $re_word) = (qr/\n/, qr/\S/);
	READING: while (1) {
		my $cnt = read($fh, $buf, $maxread, length($buf));
		unless (defined $cnt) {
			next READING if $!{EAGAIN} || $!{EINTR};
			$res{error} = 1; $res{reason} = "sysread: $!";
			last READING;
		}
		last READING if $cnt == 0; #EOF
		for ($pos = 0; $pos < length($buf); $pos ++) {
			my $char = substr($buf, $pos, 1);
			if (!$in_word) {
				if ($char =~ $re_newline) {
					$lc++ unless $has_line;
					$has_line = 0;
				} elsif ($char =~ $re_word) {
					$wc++;
					$lc ++ unless $has_line++;
					$in_word = 1;
				} else {
					$lc++ unless $has_line++;
				}
			} else {
				if ($char =~ $re_newline) {
					$lc++ unless $has_line;
					$has_line = 0;
					$in_word = 0;
				} elsif ($char =~ $re_word) {
				} else {
					$in_word = 0;
				}
			}
		}
		$buf = ''; $pos = 0;
	}
	@{$res}{qw(lines words)} = ($lc, $wc);
	return $res;
}

sub ethalon_wc_from_fd {
	my $fh  = shift or croak 'need fh';
	my @lines = <$fh>;
	my @words = grep {length $_} map {split /\s+/} @lines;
	return {error => 0, lines => 0 + @lines, words => 0 + @words};
}

1;
