package Dallycot::AST::Compose;

# ABSTRACT: Compose lambdas into a new lambda

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Promises qw(deferred);

sub execute {
  my ( $self, $engine ) = @_;

  my $d = deferred;

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

  return $d->promise;
}

1;
