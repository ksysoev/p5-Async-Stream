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

Constructor creates instanse of class. Class method gets 2 arguments item's value and generator subroutine referens to generate next item.

  my $i = 0;
  my $stream_item = Async::Stream::Item->new($i++, sub {
      my $return_cb = shift;
      $return_cb->($i++);
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
				my $val = shift;
				if (defined $val) {
					$self->[NEXT] = __PACKAGE__->new($val, $self->[NEXT])	
				} else {
					$self->[NEXT] = $val
				}
				
				$next_cb->($self->[NEXT]);
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

1; # End of Async::Stream::Item
