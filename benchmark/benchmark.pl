#!/usr/bin/env perl
#use strict;
use warnings;

use Benchmark qw/timethese cmpthese/;
binmode STDOUT, ":utf8";

# Usage: Call without options to run the whole script.
# It will call itself with options to run for both
# the pure implementation and the XSUB implementation.

my $times;

if (not defined $ARGV[0]) {   
    system './benchmark.pl -xsub';
    system './benchmark.pl -pure';
    exit;
}
if ($ARGV[0] eq '-pure') {
    require Normalize2;
    Normalize2->import(qw(NFD NFC NFKD NFKC));
    $times = 10;
    print "\n\n================ Unicode-Normalize-1.16, pure Perl version ================"
}
elsif ($ARGV[0] eq '-xsub') {
    require Unicode::Normalize;
    Unicode::Normalize->import(qw(NFD NFC NFKD NFKC));
    $times = 100;
    print "================ Unicode-Normalize-1.16, xsub (i.e. C) version ================"
}

my $dir = '.';
my $test_str;
my $char_size;
my $byte_size;
my $language;

opendir(DIR, $dir) or die $!;

while (my $file = readdir(DIR)) {

    # Use a regular expression to ignore files beginning with a period
    next if ($file !~ m/^(.*)_\.txt$/);
    $language = $1;
    open FILE, $file or die "Couldn't open file: $!";
    binmode FILE, ":utf8";
    $test_str = join('', <FILE>);
    close FILE;
    $char_size = length($test_str);
    {
        use bytes;
        $byte_size = length($test_str);
    }
    print "\n________________ " . $language . " (" . $char_size . " characters, " . $byte_size . " bytes) ________________\n\n";

    timethese($times, {
        time_NFD => sub {
            NFD($test_str);
        },
        time_NFC => sub {
            NFC($test_str);
        },
        time_NFKD => sub {
            NFKD($test_str);
        },
        time_NFKC => sub {
            NFKC($test_str);
        },
    });
}

closedir(DIR);

