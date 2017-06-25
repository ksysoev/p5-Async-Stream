package Async::Stream::Item;

use 5.006;
use strict;
use warnings;


use constant {
	VALUE => 0,
	NEXT  => 1,
};

=head1 NAME

Item for Async::Stream

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';


=head1 SYNOPSIS

Creating and managing item for Async::Stream

  use Async::Stream::Item;

  my $stream_item = Async::Stream::Item->new($value, $next_item_cb);
		
=head1 SUBROUTINES/METHODS

=head2 new($val,$generator_next_item)

Constructor creates instanse of class. 
Class method gets 2 arguments item's value and generator subroutine referens to generate next item.

  my $i = 0;
  my $stream_item = Async::Stream::Item->new($i++, sub {
      my $return_cb = shift;
      if($i < 100){
				$return_cb->($i++)
      } else {
				$return_cb->()
      }
    });

=cut

sub new {
	my ($class, $val, $next) = @_;
	bless [ $val, $next ], $class;
}

=head2 val()

Method returns item's value.

  my $value = $stream_item->val;

=cut

sub val {
	my $self = shift;
	$self->[VALUE];
}

=head2 next($next_callback);
	
Method returns next item in stream. Method gets callback to return next item.

  $stream_item->next(sub {
      my $next_stream_item = shift;
    });

=cut

sub next {
	my $self = shift;
	my $next_cb = shift;

	if (ref $self->[NEXT] eq "CODE") {
		$self->[NEXT](sub {
				if (@_) {
					$self->[NEXT] = __PACKAGE__->new($_[0], $self->[NEXT]);
					$next_cb->($self->[NEXT]);
				} else {
					$self->[NEXT] = undef;
					$next_cb->();
				}
			});
	} else {
		$next_cb->($self->[NEXT]);
	}
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

1; # End of Async::Stream::Item
