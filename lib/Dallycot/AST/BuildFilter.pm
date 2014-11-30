package Dallycot::AST::BuildFilter;

# ABSTRACT: Create lambda or filtered stream

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
      my $stream = pop @functions;
      if ( grep { !$_->isa('Dallycot::Value::Lambda') } @functions ) {
        $d->reject("All but the last term in a filter must be lambdas.");
      }
      elsif ( grep { 1 != $_->min_arity } @functions ) {
        $d->reject("All lambdas in a filter must have arity 1.");
      }
      else {
        if ( $stream->isa('Dallycot::Value::Lambda') ) {

          # we really just have a composition
          push @functions, $stream;
          my $filter = $engine->compose_filters(@functions);
          $d->resolve( $engine->make_filter($filter) );
        }
        else {
          my $filter = $engine->compose_filters(@functions);

          $stream->apply_filter( $engine, $d, $filter );
        }
      }
    },
    sub {
      $d->reject(@_);
    }
  );

  return $d->promise;
}

1;
