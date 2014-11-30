package Dallycot::AST::Sequence;

# ABSTRACT: Creates a new execution context for child nodes

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub to_string {
  my ($self) = @_;
  return join( "; ", map { $_->to_string } @{$self} );
}

sub execute {
  my ( $self, $engine ) = @_;

  return $engine->with_child_scope()->execute(@$self);
}

1;
