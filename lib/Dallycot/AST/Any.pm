package Dallycot::AST::Any;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST::LoopBase';

sub process_loop {
  my($self, $engine, $d, @expressions) = @_;

  if(!@expressions) {
    $d -> resolve($engine-> FALSE);
  }
  else {
    $engine->execute(shift @expressions, ['Boolean'])->done(sub {
      if($_[0]->value) {
        $d->resolve($engine-> TRUE);
      }
      else {
        $self -> process_loop($engine, $d, @expressions);
      }
    }, sub {
      $d -> reject(@_);
    });
  }

  return;
}

1;
