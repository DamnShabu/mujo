#!/usr/bin/env perl
use strict;
use warnings;
use Fcntl qw(:DEFAULT);

my $EV_KEY = 1;
my $KEY_LEFTMETA = 125;
my $KEY_RIGHTMETA = 126;

my $SCRIPT_DIR = $0;
$SCRIPT_DIR =~ s|/[^/]+$||;
my @TOGGLE_CMD = ("qs", "-p", "$SCRIPT_DIR/shell.qml", "ipc", "call", "launcher", "toggle");

sub is_keyboard {
    my ($path) = @_;
    my ($devname) = $path =~ m{/dev/input/event(\d+)};
    return 0 unless defined $devname;

    my $cap_path = "/sys/class/input/event$devname/device/capabilities/key";
    open my $fh, '<', $cap_path or return 0;
    my $line = <$fh>;
    close $fh;
    return 0 unless defined $line;

    # capabilities/key is a hex bitmask. Bit 1 (EV_KEY) being set means device supports keys.
    # But we want keyboards specifically. Check if any of the high key ranges (keyboards)
    # are in the bitmap. Actually, just check that the EV_KEY bit is set and
    # the device is not exclusively a relative/absolute device (mouse/touchpad).
    chomp $line;
    my @words = split /\s+/, $line;

    # A keyboard typically has many key bits set. A mouse/touchpad has few or none.
    # Count non-zero words - keyboards have lots of key capabilities.
    my $nonzero = 0;
    for my $w (@words) {
        $nonzero++ if $w !~ /^0+$/ && $w ne "";
    }
    return $nonzero > 2; # keyboards have many key capabilities, mice have few
}

my @fds;
for my $path (sort glob("/dev/input/event*")) {
    next unless is_keyboard($path);
    if (sysopen(my $fh, $path, O_RDONLY | O_NONBLOCK)) {
        push @fds, { path => $path, fh => $fh };
    }
}

warn "Warning: No keyboard devices found, Super key monitor disabled\n" and exit 0 unless @fds;

my $super_held = 0;
my $other_while_super = 0;

# Clean up file handles on exit
sub cleanup {
    for my $dev (@fds) {
        close $dev->{fh} if $dev->{fh};
    }
    exit 0;
}
$SIG{INT}  = \&cleanup;
$SIG{TERM} = \&cleanup;
$SIG{QUIT} = \&cleanup;

my $rin = '';
for my $dev (@fds) {
    vec($rin, fileno($dev->{fh}), 1) = 1;
}

while (1) {
    my $found = select(my $rout = $rin, undef, undef, undef);
    next unless $found > 0;

    for my $dev (@fds) {
        next unless vec($rout, fileno($dev->{fh}), 1);

        my $data;
        my $n = sysread($dev->{fh}, $data, 1024);
        next unless defined $n && $n > 0;

        my $offset = 0;
        while ($offset + 24 <= length($data)) {
            my @ev = unpack("qqSSl", substr($data, $offset, 24));
            $offset += 24;
            my ($sec, $usec, $ev_type, $ev_code, $ev_value) = @ev;

            next unless $ev_type == $EV_KEY;

            if ($ev_code == $KEY_LEFTMETA || $ev_code == $KEY_RIGHTMETA) {
                if ($ev_value == 1) {
                    $super_held = 1;
                    $other_while_super = 0;
                } elsif ($ev_value == 0) {
                    if ($super_held && !$other_while_super) {
                        system(@TOGGLE_CMD);
                    }
                    $super_held = 0;
                    $other_while_super = 0;
                }
            } elsif ($super_held && $ev_value == 1) {
                $other_while_super = 1;
            }
        }
    }
}
