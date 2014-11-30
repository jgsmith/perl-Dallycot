package Dallycot::AST::Lambda;

# ABSTRACT: Create a lambda value with a closure environment

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Promises qw(deferred);

use Readonly;

Readonly my $EXPRESSION             => 0;
Readonly my $BINDINGS               => 1;
Readonly my $BINDINGS_WITH_DEFAULTS => 2;
Readonly my $OPTIONS                => 3;

sub child_nodes {
  my ($self) = @_;
  return $self->[$EXPRESSION],
    ( map { $_->[1] } @{ $self->[$BINDINGS_WITH_DEFAULTS] || [] } ),
    ( values %{ $self->[$OPTIONS] || {} } );
}

sub execute {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  $d->resolve( $engine->make_lambda(@$self) );

  return $d->promise;
}

1;
