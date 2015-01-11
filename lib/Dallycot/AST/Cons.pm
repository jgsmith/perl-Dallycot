package Dallycot::AST::Cons;

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
      my($root, @things) = @_;
      $d -> resolve($root -> prepend(@things));
    },
    sub {
      $d -> reject(@_);
    }
  );

  return $d -> promise;
}

1;
