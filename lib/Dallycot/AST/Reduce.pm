package Dallycot::AST::Reduce;

use strict;
use warnings;

use parent 'Dallycot::AST';

use Readonly;

Readonly my $LAMBDA => ['Lambda'];
Readonly my $STREAM => ['Stream'];

sub execute {
  my($self, $engine, $d) = @_;

  $engine->collect(
    $self->[0],
    [ $self->[1], $LAMBDA ],
    [ $self->[2], $STREAM ]
  )->done(sub {
    my($start, $lambda, $stream) = @_;
    $stream -> reduce($engine, $start, $lambda) -> done(sub {
      $d -> resolve(@_);
    }, sub {
      $d -> reject(@_);
    });
  }, sub {
    $d -> reject(@_);
  });

  return;
}

1;
