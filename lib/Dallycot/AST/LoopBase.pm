use strict;
use warnings;
package Dallycot::AST::LoopBase;

use parent 'Dallycot::AST';

sub execute {
  my($self, $engine, $d) = @_;

  $self->_loop($engine, $d, @$self);
}

sub _loop {
  my($self, $engine, $d) = @_;

  $d -> reject("Loop body is undefined for " . ref($self) . ".");
}

1;
