package Dallycot::AST::Defined;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub to_string {
  my($self) = @_;

  return "?(" . ($self->[0]->to_string). ")";
}

sub execute {
  my($self, $engine, $d) = @_;

  $engine->execute($self->[0])->done(sub {
    my($result) = @_;
    if(ref $result) {
      $d->resolve($result->is_defined ? $engine-> TRUE : $engine-> FALSE);
    }
    else {
      $d->resolve($engine-> FALSE);
    }
  }, sub {
    $d -> reject(@_);
  });

  return;
}

1;
