package Dallycot::AST::Tail;

# ABSTRACT: Finds the rest of a collection

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';
use Carp qw(croak);

sub to_string {
  my ($self) = @_;

  return $self->[0]->to_string . '...';
}

sub execute {
  my ( $self, $engine ) = @_;

  return $engine->execute( $self->[0] )->then(
    sub {
      my ($stream) = @_;

      if ( $stream->can('tail') ) {
        return $stream->tail($engine);
      }
      else {
        croak "The tail operator requires a stream-like object.";
      }
    }
  );
}

1;
