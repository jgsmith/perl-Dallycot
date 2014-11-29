package Dallycot::AST::LoopBase;

use strict;
use warnings;

use parent 'Dallycot::AST';

sub execute {
  my($self, $engine, $d) = @_;

  $self->_loop($engine, $d, @$self);

  return;
}

sub _loop {
  my($self, $engine, $d) = @_;

  $d -> reject("Loop body is undefined for " . ref($self) . ".");

  return;
}

1;
