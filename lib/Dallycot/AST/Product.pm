package Dallycot::AST::Product;

# ABSTRACT: Calculates the product of a series of values

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Readonly;

Readonly my $NUMERIC => ['Numeric'];

sub to_string {
  my ($self) = @_;

  return "(" . join( "*", map { $_->to_string } @{$self} ) . ")";
}

sub execute {
  my ( $self, $engine ) = @_;

  return $engine->collect( map { [ $_, $NUMERIC ] } @$self )->then(
    sub {
      my (@values) = map { $_->value } @_;

      my $acc = ( pop @values )->copy;

      while (@values) {
        $acc *= ( pop @values );
      }

      return Dallycot::Value::Numeric -> new($acc);
    }
  );
}

1;
