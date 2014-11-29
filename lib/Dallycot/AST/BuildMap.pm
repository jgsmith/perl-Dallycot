package Dallycot::AST::BuildMap;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub execute {
  my ( $self, $engine, $d ) = @_;

  $engine->collect(@$self)->done(
    sub {
      my (@functions) = @_;
      my $stream = pop @functions;
      if ( grep { !$_->isa('Dallycot::Value::Lambda') } @functions ) {
        $d->reject("All but the last term in a mapping must be lambdas.");
      }
      elsif ( grep { 1 != $_->min_arity } @functions ) {
        $d->reject("All lambdas in a mapping must have arity 1.");
      }
      else {
        if ( $stream->isa('Dallycot::Value::Lambda') ) {

          # we really just have a composition
          push @functions, $stream;
          my $transform = $engine->compose_lambdas(@functions);
          $d->resolve( $engine->make_map($transform) );
        }
        else {
          my $transform = $engine->compose_lambdas(@functions);

          $stream->apply_map( $engine, $d, $transform );
        }
      }
    },
    sub {
      $d->reject(@_);
    }
  );

  return;
}

1;
