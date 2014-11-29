package Dallycot::AST::BuildVector;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub execute {
  my ( $self, $engine, $d ) = @_;

  $engine->collect(@$self)->done(
    sub {
      my (@bits) = @_;

      $d->resolve( bless \@bits => 'Dallycot::Value::Vector' );
    },
    sub {
      $d->reject(@_);
    }
  );

  return;
}

1;
