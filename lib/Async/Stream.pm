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

	$class->new(sub { shift->(shift @item) })
}

=head2 head

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

	my $item = $self->head;

	my $each; $each = sub {
		$item->next(sub {
			$item = shift;
			if (defined $item) {
				$action->($item->val);
				$each->()
			}
		});
	}; $each->();
	weaken $each;
}

sub reduce  {
	my $self = shift;
	my $code = shift;
	my $return_cb = shift;

	my $pkg = caller;
	
	$self->head->next(sub {
			my $item = shift;
			return $return_cb->() unless defined $item;
			no strict 'refs';
			my $prev = $item->val;
			my $reduce_cb; $reduce_cb = sub {
				$item->next(sub {
						$item = shift;
						if (defined $item) {
							local ${ $pkg . '::a' } = $prev;
							local ${ $pkg . '::b' } = $item->val;
							$prev = $code->();
							$reduce_cb->();
						} else {
							$return_cb->($prev);
						}
					});
			};$reduce_cb->();
			weaken $reduce_cb;
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

	my $item = $self->head;

	my $grep_cb; $grep_cb = sub {
		my $return_cb = shift;
		$item->next(sub {
			$item = shift;
			if (defined $item) { 
				local $_ = $item->val;
				if ($is_intresting->()) {
					$return_cb->($item->val);
				} else {
					$grep_cb->($return_cb)
				}
			} else {
				$return_cb->(undef)
			}
		});
	};
	
	Async::Stream->new($grep_cb);
}

sub transform {
	my $self = shift;
	my $transform = shift;
	
	
	die   unless ref $transform eq "CODE";

	my $item = $self->head;

	my $grep_cb; $grep_cb = sub {
		my $return_cb = shift;
		$item->next(sub {
			$item = shift;
			if (defined $item) { 
				local $_ = $item->val;
				$return_cb->($transform->());
			} else {
				$return_cb->(undef)
			}
		});
	};
	
	Async::Stream->new($grep_cb);
}

sub concat {
	my @streams = @_;

	my $item  = (shift @streams)->head;

	my $concat_cb; $concat_cb = sub {
		my $return_cb = shift;
		$item->next(sub {
			$item = shift;
			if (defined $item) { 
				$return_cb->($item->val);
			} else {
				if (@streams) {
					$item  = (shift @streams)->head;
					$concat_cb->($return_cb);
				} else {;
					$return_cb->(undef)	
				}
			}
		});
	};

	Async::Stream->new($concat_cb);
}

sub count {
	my $self = shift;
	my $return_cb = shift;

	my $result = 0;
	
	$self->head->next(sub {
			my $item = shift;
			return $return_cb->($result) unless defined $item;
			my $reduce_cb; $reduce_cb = sub {
				$result++;
				$item->next(sub {
						$item = shift;
						if (defined $item) {
							$reduce_cb->();
						} else {
							$return_cb->($result);
						}
					});
			};$reduce_cb->();
			weaken $reduce_cb;
		});

	return $self;
}

sub skip {
	my $self = shift;
	my $skip = int(shift);

	$skip = 0 if $skip < 0;

	if ($skip) {
		my $iterator = Async::Stream::Iterator->new($self);

		my $generator; $generator = sub {
			my $return_cb = shift;
			$iterator->next(sub {
					my $val = shift;
					if ( $skip-- > 0 ){
						$generator->($return_cb);
					} else {
						$return_cb->($val);
					}
				});
		};

		return Async::Stream->new($generator);
	} else {
		return $self;
	}
}

sub sort {
	my $self = shift;
	my $comporator = shift;

	my $sorted = 0;
	my @sorted_array;

	my $pkg = caller;

	my $generator = sub {
		my $return_cb = shift;

		unless ($sorted) {
			$self->to_arrayref(sub{
					my $array = shift;
					no strict 'refs';
					local *{ $pkg . '::a' } = *{ __PACKAGE__ . '::a' };
					local *{ $pkg . '::b' } = *{ __PACKAGE__ . '::b' };
					@sorted_array = sort { $comporator->() } @{$array};
					$sorted = 1;
					$return_cb->(shift @sorted_array);
				});
		} else {
			$return_cb->(shift @sorted_array);
		}
	};

	Async::Stream->new($generator)
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
						$prev = shift;
						if (defined $prev){
							@cur_slice = ($prev);
							$generator->($return_cb);
						} else {
							$return_cb->(undef);
						}
					});
			} else {
				$iterator->next(sub {
						no strict 'refs';
						my $val = shift;
						if (defined $val) {
							local ${ $pkg . '::a' } = $prev;
							local ${ $pkg . '::b' } = $val;
							$prev = $val;
							if ($cut->()) {
								local *{ $pkg . '::a' } = *{ __PACKAGE__ . '::a' };
								local *{ $pkg . '::b' } = *{ __PACKAGE__ . '::b' };
								@sorted_array = sort { $comporator->() } @cur_slice;
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
								@sorted_array = sort { $comporator->() } @cur_slice;
								@cur_slice = ();
								$return_cb->(shift @sorted_array);	
							} else {
								$return_cb->(undef);
							}
						}
					});
			}
		}
	};

	Async::Stream->new($generator)
}

sub to_arrayref {
	my $self = shift;
	my $return_cb = shift;

	my @result;
	
	$self->head->next(sub {
			my $item = shift;
			return $return_cb->(\@result) unless defined $item;
			my $reduce_cb; $reduce_cb = sub {
				push @result, $item->val;
				$item->next(sub {
						$item = shift;
						if (defined $item) {
							$reduce_cb->();
						} else {
							$return_cb->(\@result);
						}
					});
			};$reduce_cb->();
			weaken $reduce_cb;
		});

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
			return $return_cb->(undef) unless ($limit-- > 0);
			$iterator->next($return_cb);
		}
	} else {
		$generator = sub {
			my $return_cb = shift;
			$return_cb->(undef);
		}
	}

	Async::Stream->new($generator);
}

sub merge {}


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
