package Dallycot::AST::Identity;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub to_string {
  my ($self) = @_;

  return $self->[0]->to_string;
}

sub execute {
  my ( $self, $engine, $d ) = @_;

  $d->resolve( $self->[0] );

  return;
}

1;
