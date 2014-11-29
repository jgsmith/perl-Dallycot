package Dallycot::AST::Negation;

use strict;
use warnings;

use parent 'Dallycot::AST';

sub to_string {
  my($self) = @_;

  return "-" . $self->[0]->to_string;
}

sub execute {
  my($self, $engine, $d) = @_;

  $engine->execute($self->[0], ['Numeric'])->done(sub {
    $d -> resolve($engine->make_numeric(
      -($_[0]->value)
    ));
  }, sub {
    $d -> reject(@_);
  });

  return;
}

1;
