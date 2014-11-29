package Dallycot::AST::Expr;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub to_json {
  return +{ a => 'Expr' };
}

sub to_string { return "" }

sub execute {
  my ( $self, $engine, $d ) = @_;

  $d->resolve( $engine->UNDEFINED );

  return;
}

1;
