#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

use Async::Stream;

 plan tests => 1;

my $i = 0;
my $test_stream = Async::Stream->new(sub { $_[0]->($i++) });

isa_ok($test_stream,'Async::Stream');

# diag( "Testing Async::Stream $Async::Stream::VERSION, Perl $], $^X" );
# 	