package Dallycot::AST::LoopBase;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub execute {
  my ( $self, $engine, $d ) = @_;

  $self->process_loop( $engine, $d, @$self );

  return;
}

sub process_loop {
  my ( $self, $engine, $d ) = @_;

  $d->reject( "Loop body is undefined for " . ref($self) . "." );

  return;
}

1;
