package Dallycot::AST::Negation;

# ABSTRACT: Negate a numeric value

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub to_string {
  my ($self) = @_;

  return "-" . $self->[0]->to_string;
}

sub execute {
  my ( $self, $engine ) = @_;

  return $engine->execute( $self->[0], ['Numeric'] )->then(
    sub {
      $engine->make_numeric( -( $_[0]->value ) );
    }
  );
}

1;
