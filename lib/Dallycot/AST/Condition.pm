package Dallycot::AST::Condition;

use strict;
use warnings;

use parent 'Dallycot::AST::LoopBase';

sub child_nodes {
  my($self) = @_;

  return grep { defined } map { @{$_} } @{$self};
}

sub _loop {
  my($self, $engine, $d, $condition, @expressions) = @_;

  if($condition) {
    if(defined $condition->[0]) {
      $engine->execute($condition->[0], ['Boolean'])->done(sub {
        my($flag) = @_;
        if($flag -> value) {
          $engine->execute($condition->[1])->done(sub {
            $d -> resolve(@_);
          }, sub {
            $d -> reject(@_);
          });
        }
        else {
          $self->_loop($engine, $d, @expressions);
        }
      }, sub {
        $d -> reject(@_);
      });
    }
    else {
      $engine->execute($condition->[1])->done(sub {
        $d -> resolve(@_);
      }, sub {
        $d -> reject(@_);
      });
    }
  }
  else {
    $d->resolve($engine->UNDEFINED);
  }

  return;
}

1;
