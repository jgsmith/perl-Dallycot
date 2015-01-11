package Dallycot::AST::Head;

# ABSTRACT: Get the first value in a collection or similar value

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Carp qw(croak);

sub to_string {
  my ($self) = @_;

  return $self->[0]->to_string . "'";
}

sub execute {
  my ( $self, $engine ) = @_;

  return $engine->execute( $self->[0] )->then(
    sub {
      my ($stream) = @_;

      if ( $stream->can('head') ) {
        return $stream->head($engine);
      }
      else {
        croak "The head operator requires a stream-like object.";
      }
    }
  );

}

1;
