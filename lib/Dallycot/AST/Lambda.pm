package Dallycot::AST::Lambda;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Readonly;

Readonly my $EXPRESSION             => 0;
Readonly my $BINDINGS               => 1;
Readonly my $BINDINGS_WITH_DEFAULTS => 2;
Readonly my $OPTIONS                => 3;

sub child_nodes {
  my ($self) = @_;
  return $self->[$EXPRESSION],
    ( map { $_->[1] } @{ $self->[$BINDINGS_WITH_DEFAULTS] || [] } ),

    #(map { $_->[0] } @{$self->[$BINDINGS]||[]}),
    #@{$self->[$BINDINGS]||[]},
    ( values %{ $self->[$OPTIONS] || {} } );
}

sub execute {
  my ( $self, $engine, $d ) = @_;

  $d->resolve( $engine->make_lambda( @$self ) );

  return;
}

1;
