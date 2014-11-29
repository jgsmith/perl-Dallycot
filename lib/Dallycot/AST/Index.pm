package Dallycot::AST::Index;

use strict;
use warnings;

use parent 'Dallycot::AST';

sub execute {
  my($self, $engine, $d) = @_;

  my @expressions = @$self;

  if(@expressions) {
    $engine->execute(shift @expressions) -> done(sub {
      my($root) = @_;
      $self -> _do_next_index($engine, $d, $root, @expressions);
    }, sub {
      $d->reject(@_);
    });
  }
  else {
    $d -> reject('missing expressions');
  }

  return;
}

sub _do_next_index {
  my($self, $engine, $d, $root, $index_expr, @indices) = @_;

  if($index_expr) {
    $engine->execute($index_expr)->done(sub {
      my($index) = @_;

      if($index->isa('Dallycot::Value::Numeric')) {
        $index = $index->value;
      }
      else {
        $d -> reject("Vector indices must be numeric");
        return;
      }
      $root -> value_at($engine, $index) -> done(sub {
        $self->_do_next_index($engine, $d, $_[0], @indices);
      }, sub {
        $d -> reject(@_);
      });
    }, sub {
      $d -> reject(@_);
    });
  }
  else {
    $d -> resolve($root);
  }

  return;
}

1;
