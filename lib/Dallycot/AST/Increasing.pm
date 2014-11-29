package Dallycot::AST::Increasing;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST::ComparisonBase';

sub to_string {
  my ($self) = @_;
  return join( " <= ", map { $_->to_string } @{$self} );
}

sub compare {
  my ( $self, $engine, $left_value, $right_value ) = @_;

  return $left_value->is_less_or_equal( $engine, $right_value );
}

1;
