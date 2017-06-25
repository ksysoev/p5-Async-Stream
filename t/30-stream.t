#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

use Async::Stream;

 plan tests => 33;

### Method new ###
my $i = 0;
my $test_stream = Async::Stream->new(sub { $_[0]->($i++) });
isa_ok($test_stream,'Async::Stream');


### Method head ###
my $head = $test_stream->head;
isa_ok($head,'Async::Stream::Item');

### Method iterator ###
my $iterator = $test_stream->iterator;
isa_ok($iterator,'Async::Stream::Iterator');

### Method to_arrayref ###
my @test_array = (1,2,3,4,5);
my $array_to_compare = [@test_array];
$test_stream = Async::Stream->new(sub{$_[0]->(@test_array ? (shift @test_array):())});
$test_stream->to_arrayref(sub {
		is_deeply($_[0], $array_to_compare, "Method to_arrayref");
	});

### Method new_from ###
@test_array = (1,2,3,4,5);
$test_stream = Async::Stream->new_from(@test_array);
$test_stream->to_arrayref(sub {
		is_deeply($_[0], \@test_array, "Method new_from");
	});

### Method min ###
@test_array = (1,2,3);
$test_stream = Async::Stream->new_from(@test_array);
$test_stream->min(sub{is($_[0],'1',"Method min 1")});

@test_array = (3,2,1);
$test_stream = Async::Stream->new_from(@test_array);
$test_stream->min(sub{is($_[0],'1',"Method min 2")});

### Method max ###
@test_array = (1,2,3);
$test_stream = Async::Stream->new_from(@test_array);
$test_stream->max(sub{is($_[0],'3',"Method max 1")});

@test_array = (3,2,1);
$test_stream = Async::Stream->new_from(@test_array);
$test_stream->max(sub{is($_[0],'3',"Method max 2")});

### Method sum ###
@test_array = (1,2,3);
$test_stream = Async::Stream->new_from(@test_array);
$test_stream->sum(sub{is($_[0],'6',"Method sum")});

### Method reduce ###
@test_array = (1,2,3);
$test_stream = Async::Stream->new_from(@test_array);
$test_stream->reduce(sub{$a < $b ? $a : $b},sub{is($_[0],'1',"Method reduce find min")});
$test_stream->reduce(sub{$a > $b ? $a : $b},sub{is($_[0],'3',"Method reduce find max")});
$test_stream->reduce(sub{$a + $b},sub{is($_[0],'6',"Method reduce find sum")});

### Method filter ###
@test_array = (1,2,3);
$test_stream = Async::Stream->new_from(@test_array);
$test_stream
	->filter(sub{$_ != 2})
	->to_arrayref(sub{is_deeply($_[0],[grep {$_!=2} @test_array],"Method filter")});

### Method smap ###
@test_array = (1,2,3);
$test_stream = Async::Stream->new_from(@test_array);
$test_stream
	->smap(sub{$_ * 2})
	->to_arrayref(sub{is_deeply($_[0],[map {$_*2} @test_array],"Method smap")});

### Method transform ###
@test_array = (1,2,3);
$test_stream = Async::Stream->new_from(@test_array);
$test_stream
	->transform(sub{$_[0]->($_ * 2)})
	->to_arrayref(sub{is_deeply($_[0],[map {$_*2} @test_array],"Method transform")});

### Method count ###
@test_array = (1,2,3);
$test_stream = Async::Stream->new_from(@test_array);
$test_stream->count(sub{is($_[0],3,"Method count")});

### Method concat ###
@test_array = (1,2,3);
$test_stream = Async::Stream->new_from(@test_array);
$test_stream
	->concat($test_stream)
	->to_arrayref(sub {is_deeply($_[0], [@test_array,@test_array], "Method concat")});

### Method skip ###
@test_array = (1,2,3);
$test_stream = Async::Stream->new_from(@test_array);
$test_stream
	->skip(1)
	->to_arrayref(sub {is_deeply($_[0], [2,3], "Method skip 1")});

$test_stream = Async::Stream->new_from(@test_array);
$test_stream
	->skip(0)
	->to_arrayref(sub {is_deeply($_[0], [@test_array], "Method skip 2")});

$test_stream = Async::Stream->new_from(@test_array);
$test_stream
	->skip(-1)
	->to_arrayref(sub {is_deeply($_[0], [@test_array], "Method skip 3")});

### Method limit ###
@test_array = (1,2,3);
$test_stream = Async::Stream->new_from(@test_array);
$test_stream
	->limit(1)
	->to_arrayref(sub {is_deeply($_[0], [$test_array[0]], "Method limit 1")});

$test_stream = Async::Stream->new_from(@test_array);
$test_stream
	->limit(0)
	->to_arrayref(sub {is_deeply($_[0], [], "Method limit 2")});

$test_stream = Async::Stream->new_from(@test_array);
$test_stream
	->limit(-1)
	->to_arrayref(sub {is_deeply($_[0], [], "Method limit 3")});

### Method sort ###
@test_array = (3,1,2);
$test_stream = Async::Stream->new_from(@test_array);
$test_stream
	->sort(sub{$a <=> $b})
	->to_arrayref(sub{is_deeply($_[0],[sort {$a <=> $b} @test_array],"Method sort")});

### Method cut_sort ###
@test_array = (2,1,30,20,5,6);
$test_stream = Async::Stream->new_from(@test_array);
$test_stream
	->cut_sort(sub {length($a) != length($b)},sub {$a <=> $b})
	->to_arrayref(sub{is_deeply($_[0],[1,2,20,30,5,6],"Method cut_sort 1")});

@test_array = (2,1,30,20,5,6);
$test_stream = Async::Stream->new_from(@test_array);
$test_stream
	->limit(0)
	->cut_sort(sub {length($a) != length($b)},sub {$a <=> $b})
	->to_arrayref(sub{is_deeply($_[0],[],"Method cut_sort 2")});

### Method peek ###
@test_array = (1,2,3);
$test_stream = Async::Stream->new_from(@test_array);
$test_stream->peek(sub{is($_,shift @test_array,"Method peek")})->to_arrayref(sub {});

### Method each ###
@test_array = (1,2,3);
$test_stream = Async::Stream->new_from(@test_array);
$test_stream->each(sub{is(shift,shift @test_array,"Method each")});



diag( "Testing Async::Stream $Async::Stream::VERSION, Perl $], $^X" );
 	