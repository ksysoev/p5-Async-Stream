#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

use Async::Stream;
use Async::Stream::Iterator;

plan tests => 2;

my $i = 0;
my $test_stream = Async::Stream->new(sub {$_[0]->($i++)});
my $iterator = Async::Stream::Iterator->new($test_stream);

isa_ok($iterator,'Async::Stream::Iterator');

$iterator->next(sub {
		my $next_val = shift;
		is($next_val, 0, "Get next item");
	});


diag( "Testing Async::Stream $Async::Stream::Item::VERSION, Perl $], $^X" );
	