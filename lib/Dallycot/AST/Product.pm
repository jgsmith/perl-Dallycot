package Dallycot::AST::Product;

use strict;
use warnings;

use parent 'Dallycot::AST';

use Readonly;

Readonly my $NUMERIC => [ 'Numeric' ];

sub to_string {
  my($self) = @_;

  return "(" . join("*", map { $_ -> to_string } @{$self}) . ")"
}

sub execute {
  my($self, $engine, $d) = @_;

  $engine->collect(
    map { [ $_, $NUMERIC ] } @$self
  ) -> done( sub {
    my(@values) = map { $_->value } @_;

    my $acc = (pop @values)->copy;

    while(@values) {
      $acc *= (pop @values)
    }
    $d->resolve($engine -> make_numeric($acc));
  }, sub {
    $d -> reject(@_);
  });

  return;
}

1;
