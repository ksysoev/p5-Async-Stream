# NAME

Async::Stream - it's convenient way to work with async data flow.

IMPORTANT! PUBLIC INTERFACE ISN'T STABLE, DO NOT USE IN PRODACTION BEFORE VERSION 1.0.

# VERSION

Version 0.07

# SYNOPSIS

Module helps to organize your async code to stream.

    use Async::Stream;

    my @urls = qw(
        http://ucoz.com
        http://ya.ru
        http://google.com
      );

    my $stream = Async::Stream->new_from(@urls);

    $stream
      ->transform(sub {
          $return_cb = shift;
          http_get $_, sub {
              $return_cb->({headers => $_[0], body => $_[0]})
            };
        })
      ->filter(sub { $_->{headers}->{Status} =~ /^2/ })
      ->for_each(sub {
          my $item = shift;
          print $item->{body};
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

## new\_from(@array\_of\_items)

Constructor creates instance of class. 
Class method gets a list of items which are used for generating streams.

    my @domains = qw(
      ucoz.com
      ya.ru
      googl.com
    );
    
    my $stream = Async::Stream->new_from(@urls)

## head()

Method returns stream's head item. 
Head is a instance of class Async::Stream::Item.

    my $stream_head = $stream->head;

## prefetch($number)

Method returns stream's head item. 
Head is a instance of class Async::Stream::Item.

    my $stream_head = $stream->head;

## iterator()

Method returns stream's iterator. 
Iterator is a instance of class Async::Stream::Iterator.

    my $stream_iterator = $stream->iterator;

## to\_arrayref($returing\_cb)

Method returns stream's iterator.

    $stream->to_arrayref(sub {
        $array_ref = shift;

        #...      
      });

## for\_each($action)

Method execute action on each item in stream.

    $stream->to_arrayref(sub {
        $array_ref = shift;
        
        #...      
      });

## peek($action)

This method helps to debug streams data flow. 
You can use this method for printing or logging steam data and track data 
mutation between stream's transformations.

    $stream->peek(sub { print $_, "\n" })->to_arrayref(sub {print @{$_[0]}});

## filter($predicate)

The method filters current stream. Filter works like lazy grep.

    $stream->filter(sub {$_ % 2})->to_arrayref(sub {print @{$_[0]}});

## smap($transformer)

Method smap transforms current stream. Transform works like lazy map.

    $stream->transform(sub {$_ * 2})->to_arrayref(sub {print @{$_[0]}});

## transform($transformer)

Method transform current stream. 
Transform works like lazy map with async response. 
You can use the method for example for async http request or another async 
operation.

    $stream->transform(sub {
            $return_cb = shift;
        $return_cb->($_ * 2)
      })->to_arrayref(sub {print @{$_[0]}});

## reduce($accumulator, $returing\_cb)

Performs a reduction on the items of the stream.

    $stream->reduce(
      sub{ $a + $b }, 
      sub {
          $sum = shift 
                    #...
      });

## sum($returing\_cb)

The method computes sum of all items in stream.

    $stream->sum(
      sub {
          $sum = shift 
                    #...
      });

## min($returing\_cb)

The method finds out minimum item among all items in stream.

    $stream->min(
      sub {
          $sum = shift 
                    #...
      });

## max($returing\_cb)

The method finds out maximum item among all items in stream.

    $stream->max(
      sub {
          $sum = shift 
                    #...
      });

## append(@list\_of\_another\_streams)

The method appends several streams to tail of current stream.

    $stream->append($stream1)->to_arrayref(sub {print @{$_[0]}}); 

## count($returing\_cb)

The method counts number items in streams.

    $stream->count(sub {
        $count = shift;
      }); 

## skip($number)

The method skips $number items in stream.

    $stream->skip(5)->to_arrayref(sub {print @{$_[0]}});

## limit($number)

The method limits $number items in stream.

    $stream->limit(5)->to_arrayref(sub {print @{$_[0]}});

## arrange($comparator)

The method sorts whole stream.

    $stream->arrange(sub{$a <=> $b})->to_arrayref(sub {print @{$_[0]}});

## cut\_arrange($predicate, $comparator)

Sometimes stream can be infinity and you can't you $stream->arrange, 
you need certain parts of streams for example cut part by length of items.

    $stream
      ->cut_arrange(sub {length $a != length $b},sub {$a <=> $b})
      ->to_arrayref(sub {print @{$_[0]}});

## merge {comparator} $stream1, $stream2;

Merge two or more stream by comparing each item of stream and return new stream.

    my $ordered_stream = merge {$a <=> $b} $stream1, $stream2;

## branch {predicat} $stream;

Split stream into 2 stream are divided by predicat. Branch returns 2 streams.
First stream will contain "true" items, Second - "false" items;

    my ($success_stream, $error_stream) 
      = branch {$_->{headers}{status} == 200} $stream;

## any($predicat, $return\_cb)

Method look for any equivalent item in steam. if there is any then return that.
if there isn't  then return nothing.

    $stream->any(sub {$_ % 2})->to_arrayref(sub {print @{$_[0]}});

## distinct($key\_generator)

Method discards duplicate items from stream. 
By default uniqueness of items will be determined by textual representation of item.

    $stream->distinct(sub {$_->{name}})->to_arrayref(sub {print @{$_[0]}});

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
