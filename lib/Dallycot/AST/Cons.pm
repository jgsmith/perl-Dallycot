package Dallycot::AST::Cons;

# ABSTRACT: Compose lambdas into a new lambda

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Promises qw(deferred);

sub execute {
  my ( $self, $engine ) = @_;

  return $engine->collect(@$self)->then(
    sub {
      my ( $root, @things ) = @_;
      $root->prepend(@things);
    }
  );
}

1;
