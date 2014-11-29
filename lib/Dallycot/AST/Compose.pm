package Dallycot::AST::Compose;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub execute {
  my ( $self, $engine, $d ) = @_;

  $engine->collect(@$self)->done(
    sub {
      my (@functions) = @_;
      if ( grep { !$_->isa('Dallycot::Value::Lambda') } @functions ) {
        $d->reject("All terms in a function composition must be lambdas");
      }
      elsif ( grep { 1 != $_->min_arity } @functions ) {
        $d->reject("All lambdas in a function composition must have arity 1");
      }
      else {
        $d->resolve( $engine->compose_lambdas(@functions) );
      }
    },
    sub {
      $d->reject(@_);
    }
  );

  return;
}

1;
