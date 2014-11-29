package Dallycot::AST::All;

use strict;
use warnings;

use parent 'Dallycot::AST::LoopBase';

sub new {
  my($class, @exprs) = @_;

  $class = ref $class || $class;
  return bless \@exprs => $class;
}

sub _loop {
  my($self, $engine, $d, @expressions) = @_;

  if(!@expressions) {
    $d -> resolve($engine-> TRUE);
  }
  else {
    $engine->execute(shift @expressions, ['Boolean'])->done(sub {
      if($_[0]->value) {
        $self->_loop($engine, $d, @expressions);
      }
      else {
        $d->resolve($engine-> FALSE);
      }
    }, sub {
      $d -> reject(@_);
    });
  }

  return;
}

1;
