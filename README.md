# NAME

Async::Stream - it's convenient way to work with async data flow.

# VERSION

Version 0.11

# SYNOPSIS

Module helps to organize your async code to stream.

    use Async::Stream;

    my @urls = qw(
        http://ucoz.com
        http://ya.ru
        http://google.com
      );

    my $stream = Async::Stream::FromArray->new(@urls);

    $stream
      ->transform(sub {
          $return_cb = shift;
          http_get $_, sub {
              $return_cb->({headers => $_[0], body => $_[0]})
            };
        })
      ->grep(sub { $_->{headers}->{Status} =~ /^2/ })
      ->each(sub {
          print $_->{body};
        });

# SUBROUTINES/METHODS

## new($generator)

Constructor creates instance of class. 
Class method gets 1 arguments - generator subroutine references to generate items.
Generator will get a callback which it will use for returning result. 
If generator is exhausted then returning callback is called without arguments.

    my $i = 0;
    my $stream = Async::Stream->new(sub {
        $return_cb = shift;
        if ($i < 10) {
          $return_cb->($i++);
        } else {
          $return_cb->();
        }
      });

## head()

Method returns stream's head item. 
Head is a instance of class Async::Stream::Item.

    my $stream_head = $stream->head;

## set\_prefetch($number)

Method returns stream's head item. 
Head is a instance of class Async::Stream::Item.

    $stream->set_prefetch(4);

## iterator()

Method returns stream's iterator. 
Iterator is a instance of class Async::Stream::Iterator.

    my $stream_iterator = $stream->iterator;

## shift($return\_cb)

Remove first item from stream and return it to return callback

    $stream->shift(sub {
      if (@_){
        my $item = shift;

        ...
      }
    });

# CONVEYOR METHODS

## peek($action)

This method helps to debug streams data flow. 
You can use this method for printing or logging steam data and track data 
mutation between stream's transformations.

    $stream->peek(sub { print $_, "\n" })->to_arrayref(sub {print @{$_[0]}});

## grep($predicate)

The method greps current stream. Filter works like lazy grep.

    $stream->grep(sub {$_ % 2})->to_arrayref(sub {print @{$_[0]}});

## map($transformer)

Method makes synchronous transformation for stream, like usual map for array.

    $stream->map(sub { $_ * 2 })->to_arrayref(sub {print @{$_[0]}});

## transform($transformer)

Method transform current stream. 
Transform works like lazy map with async response. 
You can use the method for example for async http request or another async 
operation.

    $stream->transform(sub {
        $return_cb = shift;
        $return_cb->($_ * 2)
      })->to_arrayref(sub {print @{$_[0]}});

## append(@list\_streams)

The method appends one or several streams to tail of current stream.

    $stream->append($stream1)->to_arrayref(sub {print @{$_[0]}}); 

## skip($number)

The method skips $number items in stream.

    $stream->skip(5)->to_arrayref(sub {print @{$_[0]}});

## limit($number)

The method limits $number items in stream.

    $stream->limit(5)->to_arrayref(sub {print @{$_[0]}});

## spray($number)

The method helps to divide items of stream to several items. 
For example you can use this method to get some page, 
then get all link from that page and make from these link another items.

    $stream->spray(sub{ return (1 .. $_) })->to_arrayref(sub {print @{$_[0]}});

## sort($comparator)

The method sorts whole stream.

    $stream->sort(sub{$a <=> $b})->to_arrayref(sub {print @{$_[0]}});

## cut\_sort($predicate, $comparator)

Sometimes stream can be infinity and you can't you $stream->sort, 
you need certain parts of streams for example cut part by length of items.

    $stream
      ->cut_sort(sub {length $a != length $b},sub {$a <=> $b})
      ->to_arrayref(sub {print @{$_[0]}});

## reverse()

Revers order of stream's items. Can't be done on endless stream.

    $stream->reverse;

## merge\_in($comparator, @list\_streams);

Merge additional streams into current stream by comparing each item of stream.

    $stream->merge_in(sub{$a <=> $b}, $stream1, $stream2);

## $branch\_stream branch\_out($predicat);

Method makes new branch of current stream by predicate.

    my $error_stream = $stream->branch_out(sub{$_->{headers}{status} != 200});

## distinct($key\_generator)

Method discards duplicate items from stream. 
By default uniqueness of items will be determined by textual representation of item.

    $stream->distinct(sub {$_->{name}})->to_arrayref(sub {print @{$_[0]}});

# TERMINAL METHODS

## to\_arrayref($returing\_cb)

Method returns stream's iterator.

    $stream->to_arrayref(sub {
        $array_ref = shift;

        #...
      });

## each($action)

Method execute action on each item in stream.

    $stream->each(sub {
        print $_, "\n";
      });

## shift\_each($action)

Method acts like each,but after process item, it removes them from the stream

    $stream->shift_each(sub {
        print $_, "\n";
      });

## reduce($accumulator, $returing\_cb)

Performs a reduction on the items of the stream.

    $stream->reduce(
      sub{ $a + $b }, 
      sub {
        my $sum_of_items = shift;

        ...
      });

## sum($returing\_cb)

The method computes sum of all items in stream.

    $stream->sum(
      sub {
        my $sum_of_items = shift;

        ...
      });

## min($returing\_cb)

The method finds out minimum item among all items in stream.

    $stream->min(
      sub {
        my $min_item = shift;
        
        ...
      });

## max($returing\_cb)

The method finds out maximum item among all items in stream.

    $stream->max(
      sub {
        my $max_item = shift;

        ...
      });

## count($returing\_cb)

The method counts number items in streams.

    $stream->count(sub {
        my $count = shift;
      }); 

## any($predicat, $return\_cb)

Method look for any equivalent item in steam. if there is any then return that.
if there isn't  then return nothing.

    $stream->any(sub {$_ % 2}, sub{
      my $odd_item = shift

      ...
    });

# AUTHOR

Kirill Sysoev, `<k.sysoev at me.com>`

# BUGS AND LIMITATIONS

Please report any bugs or feature requests to 
[https://github.com/pestkam/p5-Async-Stream/issues](https://github.com/pestkam/p5-Async-Stream/issues).

# SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Async::Stream::Item

# LICENSE AND COPYRIGHT

Copyright 2017 Kirill Sysoev.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

[http://www.perlfoundation.org/artistic\_license\_2\_0](http://www.perlfoundation.org/artistic_license_2_0)
