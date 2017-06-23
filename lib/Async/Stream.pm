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

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

		use Async::Stream;

		my $foo = Async::Stream->new();
		...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 new
	
=cut

sub new {
	my $class = shift;
	my $next_item_callback = shift;

	my $self = {
			_head =>  Async::Stream::Item->new(undef, $next_item_callback),
		};

	bless $self, $class;
}

sub new_from {
	my $class = shift;
	my @item = @_;

	$class->new(sub { $_[0]->(@item ? (shift @item) : ()) })
}

=head2 head
Method returns stream's head item.

  my $stream_head = $stream->head;
=cut

sub head {
	my $self = shift;
	$self->{_head};
}

sub iterator {
	my $self = shift;

	Async::Stream::Iterator->new($self);
}

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

sub sum {
	my $self = shift;
	my $return_cb = shift;

	$self->reduce(sub{$a+$b}, $return_cb);

	return $self;
}

sub min {
	my $self = shift;
	my $return_cb = shift;

	$self->reduce(sub{$a < $b ? $a : $b}, $return_cb);

	return $self;
}

sub max {
	my $self = shift;
	my $return_cb = shift;

	$self->reduce(sub{$a > $b ? $a : $b}, $return_cb);

	return $self;
}

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

sub transform {
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


=head1 AUTHOR

Kirill Sysoev, C<< <k.sysoev at me.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-async-stream at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Async-Stream>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

		perldoc Async::Stream


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Async-Stream>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Async-Stream>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Async-Stream>

=item * Search CPAN

L<http://search.cpan.org/dist/Async-Stream/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2017 Kirill Sysoev.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Async::Stream
