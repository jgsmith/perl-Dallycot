package Dallycot::AST::Reduce;

# ABSTRACT: Calculates the reduction of a series of values with a lambda

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Readonly;

Readonly my $LAMBDA => ['Lambda'];
Readonly my $STREAM => ['Stream'];

sub execute {
  my ( $self, $engine ) = @_;

  return $engine->collect(
    $self->[0],
    [ $self->[1], $LAMBDA ],
    [ $self->[2], $STREAM ]
    )->then(
    sub {
      my ( $start, $lambda, $stream ) = @_;
      $stream->reduce( $engine, $start, $lambda );
    }
    );
}

1;
