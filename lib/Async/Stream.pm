package Async::Stream;

use 5.006;
use strict;
use warnings;

use Async::Stream::Item;
use Async::Stream::Iterator;
use Scalar::Util qw(weaken);

=head1 NAME

Async::Stream - it's convinient way to work with async data flow.

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';


=head1 SYNOPSIS

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
    ->each(sub {
        my $item = shift;
        print $item->{body};
      });

=head1 SUBROUTINES/METHODS

=head2 new($generator)

Constructor creates instanse of class. Class method gets 1 arguments - generator subroutine referens to generate items.
Generator will get a callback which it will use for returning result. If generator is exhausted then returning callback is called without arguments.

  my $i = 0;
  my $stream = Async::Stream->new(sub {
      $return_cb = shift;
      if ($i < 10) {
        $return_cb->($i++);
      } else {
        $return_cb->();
      }
    });
=cut
sub new {
	my $class = shift;
	my $next_item_callback = shift;

	my $self = {
			_head =>  Async::Stream::Item->new(undef, $next_item_callback),
		};

	bless $self, $class;
}

=head2 new_from(@array_of_items)

Constructor creates instanse of class. Class method gets a list of items which are used for generating streams.
	
  my @domains = qw(
    ucoz.com
    ya.ru
    googl.com
  );
  
  my $stream = Async::Stream->new_from(@urls)

=cut
sub new_from {
	my $class = shift;
	my @item = @_;

	$class->new(sub { $_[0]->(@item ? (shift @item) : ()) })
}

=head2 head()

Method returns stream's head item. Head is a instance of class Async::Stream::Item.

  my $stream_head = $stream->head;
=cut
sub head {
	my $self = shift;
	$self->{_head};
}

=head2 iterator()

Method returns stream's iterator. Iterator is a instance of class Async::Stream::Iterator.

  my $stream_iterator = $stream->iterator;
=cut

sub iterator {
	my $self = shift;

	Async::Stream::Iterator->new($self);
}

=head2 to_arrayref($returing_cb)

Method returns stream's iterator.

  $stream->to_arrayref(sub {
      $array_ref = shift;

      #...	
    });
=cut
sub to_arrayref {
	my $self = shift;
	my $return_cb = shift;

	my @result;

	my $iterator = $self->iterator;

	my $next_cb; $next_cb = sub {
		my $next_cb = $next_cb;
		$iterator->next(sub {
				if (@_) {
					push @result, $_[0];
					$next_cb->();
				} else {
					$return_cb->(\@result);
				}
			});
	};$next_cb->();	
	weaken $next_cb;

	return $self;
}

=head2 each($action)

Method execute action on each item in stream.

  $stream->to_arrayref(sub {
      $array_ref = shift;
      
      #...	
    });
=cut
sub each {
	my $self = shift;
	my $action = shift;

	my $iterator = $self->iterator;

	my $each; $each = sub {
		my $each = $each;
		$iterator->next(sub {
			if (@_) {
				$action->($_[0]);
				$each->()
			}
		});
	}; $each->();
	weaken $each;

	return $self;
}

=head2 peek($action)

This method helps to debug streams data flow. 
You can use this method for printing or logging steam data and track data mutation between stream's transformations.

  $stream->peek(sub { print $_, "\n" })->to_arrayref(sub {print @{$_[0]}});
=cut
sub peek {
	my $self = shift;
	my $action = shift;

	my $iterator = $self->iterator;
	my $generator = sub {
			my $return_cb = shift;
			$iterator->next(sub {
					if (@_) {
						local *{_} = \$_[0];
						$action->();
						$return_cb->($_[0]);
					} else {
						$return_cb->()
					}
				});
		};

	return $self = Async::Stream->new($generator);
}

=head2 filter($predicat)

The method filters current stream. Filter works like lazy grep.

  $stream->filter(sub {$_ % 2})->to_arrayref(sub {print @{$_[0]}});

=cut
sub filter {
	my $self = shift;
	my $is_intresting = shift;

	my $iterator = $self->iterator;

	my $next_cb; $next_cb = sub {
		my $return_cb = shift;
		$iterator->next(sub {
			if (@_) { 
				local *{_} = \$_[0];
				if ($is_intresting->()) {
					$return_cb->($_[0]);
				} else {
					$next_cb->($return_cb)
				}
			} else {
				$return_cb->()
			}
		});
	};
	
	return $self = Async::Stream->new($next_cb);
}

=head2 smap($transformer)

Method smap transforms current stream. Transform works like lazy map.

  $stream->transform(sub {$_ * 2})->to_arrayref(sub {print @{$_[0]}});

=cut
sub smap {
	my $self = shift;
	my $transform = shift;

	my $iterator = $self->iterator;

	my $next_cb; $next_cb = sub {
		my $return_cb = shift;
		$iterator->next(sub {
			if (@_) { 
				local *{_} = \$_[0];
				$return_cb->($transform->());
			} else {
				$return_cb->()
			}
		});
	};
	
	return $self = Async::Stream->new($next_cb);
}

=head2 transform($transformer)

Method transform current stream. Transform works like lazy map with async response. 
You can use the method for example for async http request or another async operation.

  $stream->transform(sub {
  	  $return_cb = shift;
      $return_cb->($_ * 2)
    })->to_arrayref(sub {print @{$_[0]}});

=cut
sub transform {
	my $self = shift;
	my $transform = shift;

	my $iterator = $self->iterator;

	my $next_cb; $next_cb = sub {
		my $return_cb = shift;
		$iterator->next(sub {
			if (@_) { 
				local *{_} = \$_[0];
				$transform->($return_cb);
			} else {
				$return_cb->()
			}
		});
	};
	
	return $self = Async::Stream->new($next_cb);
}

=head2 reduce($accumulator, $returing_cb)

Performs a reduction on the items of the stream.

  $stream->reduce(
    sub{ $a + $b }, 
    sub {
    	$sum = shift 
		  #...
    });

=cut
sub reduce  {
	my $self = shift;
	my $code = shift;
	my $return_cb = shift;

	my $pkg = caller;

	my $iterator = $self->iterator;

	$iterator->next(sub {
			if (@_) {
				my $prev = $_[0];
				no strict 'refs';
				my $reduce_cb; $reduce_cb = sub {
					my $reduce_cb = $reduce_cb;
					$iterator->next(sub {
							if (@_) {
								local *{ $pkg . '::a' } = \$prev;
								local *{ $pkg . '::b' } = \$_[0];
								$prev = $code->();
								$reduce_cb->();
							} else {
								$return_cb->($prev);
							}
						});
				};$reduce_cb->();
				weaken $reduce_cb;
			}	else {
				$return_cb->();
			}
		});

	return $self;
}

=head2 sum($returing_cb)

The method computes sum of all items in stream.

  $stream->sum(
    sub {
    	$sum = shift 
		  #...
    });
=cut
sub sum {
	my $self = shift;
	my $return_cb = shift;

	$self->reduce(sub{$a+$b}, $return_cb);

	return $self;
}

=head2 min($returing_cb)

The method finds out minimum item among all items in stream.

  $stream->min(
    sub {
    	$sum = shift 
		  #...
    });
=cut
sub min {
	my $self = shift;
	my $return_cb = shift;

	$self->reduce(sub{$a < $b ? $a : $b}, $return_cb);

	return $self;
}

=head2 max($returing_cb)

The method finds out maximum item among all items in stream.

  $stream->max(
    sub {
    	$sum = shift 
		  #...
    });
=cut
sub max {
	my $self = shift;
	my $return_cb = shift;

	$self->reduce(sub{$a > $b ? $a : $b}, $return_cb);

	return $self;
}

=head2 concat(@list_of_another_streams)

The method concatenates several streams.

  $stream->concat($stream1)->to_arrayref(sub {print @{$_[0]}}); 
=cut
sub concat {
	my $self = shift;
	my @streams = @_;

	my $iterator = $self->iterator;

	my $generator; $generator = sub {
		my $return_cb = shift;
		$iterator->next(sub {
				if (@_){
					$return_cb->($_[0]);
				} elsif (@streams) {
					$iterator = (shift @streams)->iterator;
					$generator->($return_cb);
				} else {
					$return_cb->();
				}
			});
	};

	return $self = Async::Stream->new($generator);
}

=head2 count($returing_cb)

The method counts number items in streams.

  $stream->count(sub {
      $count = shift;
    }); 
=cut
sub count {
	my $self = shift;
	my $return_cb = shift;

	my $result = 0;
	my $iterator = $self->iterator;

	my $next_cb ; $next_cb = sub {
		my $next_cb = $next_cb;
		$iterator->next(sub {
				if (@_) {
					$result++;
					return $next_cb->();
				}
				$return_cb->($result)
			});
	}; $next_cb->();
	weaken $next_cb;
	
	return $self;
}

=head2 skip($number)

The method skips $number items in stream.

  $stream->skip(5)->to_arrayref(sub {print @{$_[0]}});
=cut
sub skip {
	my $self = shift;
	my $skip = int(shift);

	$skip = 0 if $skip < 0;

	if ($skip) {
		my $iterator = $self->iterator;
		my $generator; $generator = sub {
			my $return_cb = shift;
			$iterator->next(sub {
					if (@_){
						if ($skip-- > 0) {
							$generator->($return_cb);	
						} else {
							$return_cb->($_[0]);
						}
					} else {
						$return_cb->();
					}
				});
		};

		return $self = Async::Stream->new($generator);
	} else {
		return $self;
	}
}

=head2 limit($number)

The method limits $number items in stream.

  $stream->limit(5)->to_arrayref(sub {print @{$_[0]}});
=cut
sub limit {
	my $self = shift;
	my $limit = int(shift);

	$limit = 0 if $limit < 0;

	my $generator;
	if ($limit) {
		my $iterator = $self->iterator;

		$generator = sub {
			my $return_cb = shift;
			return $return_cb->() unless ($limit-- > 0);
			$iterator->next($return_cb);
		}
	} else {
		$generator = sub {
			my $return_cb = shift;
			$return_cb->();
		}
	}

	return $self = Async::Stream->new($generator);
}

=head2 sort($comporator)

The method sorts whole stream.

  $stream->sort(sub{$a <=> $b})->to_arrayref(sub {print @{$_[0]}});
=cut
sub sort {
	my $self = shift;
	my $comporator = shift;
	my $pkg = caller;

	my $sorted = 0;
	my @sorted_array;
	my $stream = $self;

	my $generator = sub {
		my $return_cb = shift;

		unless ($sorted) {
			$stream->to_arrayref(sub{
					my $array = shift;
					if (@{$array}) {
						no strict 'refs';
						local *{ $pkg . '::a' } = *{ __PACKAGE__ . '::a' };
						local *{ $pkg . '::b' } = *{ __PACKAGE__ . '::b' };
						@sorted_array = sort $comporator @{$array};
						$sorted = 1;
						$return_cb->(shift @sorted_array);
					} else {
						$return_cb->();
					}
				});
		} else {
			$return_cb->(@sorted_array ? shift(@sorted_array) : ());
		}
	};

	return $self = Async::Stream->new($generator);
}

=head2 cut_sort($predicat, $comporator)

Sometimes stream can be infinity and you can't you $stream->sort, you need certain parts of streams
for example cut part by lenght of items.

  $stream->cut_sort(sub {lenght $a != lenght $b},sub {$a <=> $b})->to_arrayref(sub {print @{$_[0]}});
=cut
sub cut_sort {
	my $self = shift;
	my $cut = shift;
	my $comporator = shift;

	my $pkg = caller;
	
	my $iterator = $self->iterator;

	my $prev;
	my @cur_slice;
	my @sorted_array;
	my $generator; $generator = sub {
		my $return_cb = shift;
		if (@sorted_array) {
			$return_cb->(shift @sorted_array);
		} else {
			unless (defined $prev) {
				$iterator->next(sub {
						if (@_){
							$prev = $_[0];
							@cur_slice = ($prev);
							$generator->($return_cb);
						} else {
							$return_cb->();
						}
					});
			} else {
				$iterator->next(sub {
						no strict 'refs';
						if (@_) {
							local ${ $pkg . '::a' } = $prev;
							local ${ $pkg . '::b' } = $_[0];
							$prev = $_[0];
							if ($cut->()) {
								local *{ $pkg . '::a' } = *{ __PACKAGE__ . '::a' };
								local *{ $pkg . '::b' } = *{ __PACKAGE__ . '::b' };
								@sorted_array = sort $comporator @cur_slice;
								@cur_slice = ($prev);
								$return_cb->(shift @sorted_array);
							} else {
								push @cur_slice, $prev;
								$generator->($return_cb);
							}
						} else {
							if (@cur_slice) {
								local *{ $pkg . '::a' } = *{ __PACKAGE__ . '::a' };
								local *{ $pkg . '::b' } = *{ __PACKAGE__ . '::b' };
								@sorted_array = sort $comporator @cur_slice;
								@cur_slice = ();
								$return_cb->(shift @sorted_array);	
							} else {
								$return_cb->();
							}
						}
					});
			}
		}
	};

	return $self = Async::Stream->new($generator)
}

=head1 AUTHOR

Kirill Sysoev, C<< <k.sysoev at me.com> >>

=head1 BUGS

Please report any bugs or feature requests to L<https://github.com/pestkam/p5-Async-Stream/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

  perldoc Async::Stream::Item


=head1 LICENSE AND COPYRIGHT

Copyright 2017 Kirill Sysoev.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

=cut

1; # End of Async::Stream
