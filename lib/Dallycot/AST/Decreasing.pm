package Dallycot::AST::Decreasing;

use strict;
use warnings;

use parent 'Dallycot::AST::ComparisonBase';

sub to_string {
  my($self) = @_;

  return join(" >= ", map { $_->to_string } @{$self})
}

sub _compare {
  my($self, $engine, $left_value, $right_value) = @_;

  return $left_value->is_greater_or_equal($engine, $right_value);
}

1;
