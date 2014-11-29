package Dallycot::AST::Assign;

use strict;
use warnings;

use parent 'Dallycot::AST';

sub to_string {
  my($self) = @_;

  return $self->[0] . " := " . $self->[1]->to_string
}

sub execute {
  my($self, $engine, $d) = @_;

  my $registry = Dallycot::Registry -> instance;

  if($registry->has_assignment('', $self->[0])) {
    $d -> reject('Core definitions may not be redefined.');
  }
  $engine->execute($self->[1])->then(sub {
    my($result) = @_;
    $engine -> add_assignment($self->[0], $result);
    $d -> resolve($result);
  }) -> done(sub {}, sub {
    $d -> reject(@_);
  });
  return;
}

1;
