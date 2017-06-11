#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 2;

BEGIN {
    use_ok( 'Async::Stream' ) || print "Bail out!\n";
    use_ok( 'Async::Stream::Item' ) || print "Bail out!\n";
}

diag( "Testing Async::Stream $Async::Stream::VERSION, Perl $], $^X" );
