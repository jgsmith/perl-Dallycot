package Dallycot::AST::Reciprocal;

# ABSTRACT: Calculates the reciprocal of a numeric value

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Readonly;

Readonly my $NUMERIC => ['Numeric'];

sub to_string {
  my ($self) = @_;

  return "1/(" . $self->[0]->to_string . ")";
}

sub execute {
  my ( $self, $engine ) = @_;

  return $engine->execute( $self->[0], $NUMERIC )->then(
    sub {
      Dallycot::Value::Numeric -> new( 1 / ( $_[0]->value ) );
    }
  );
}

1;
