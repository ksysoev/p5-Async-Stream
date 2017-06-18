#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

use Async::Stream::Item;

plan tests => 3;

my $i = 0;
my $item = Async::Stream::Item->new(
	$i++,
	sub {
		my $return_cb = shift;
		$return_cb->($i++)
	});

isa_ok($item,'Async::Stream::Item');

is($item->val, 0, "Return item's value");

$item->next(sub {
		my $next_item = shift;
		is($next_item->val, 1, "Get next item");		
	});


diag( "Testing Async::Stream $Async::Stream::Item::VERSION, Perl $], $^X" );
	