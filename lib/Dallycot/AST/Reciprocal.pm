package Dallycot::AST::Reciprocal;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Readonly;

Readonly my $NUMERIC => ['Numeric'];

sub to_string {
  my ($self) = @_;

  return "1/(" . $self->[0]->to_string . ")";
}

sub execute {
  my ( $self, $engine, $d ) = @_;

  $engine->execute( $self->[0], $NUMERIC )->done(
    sub {
      $d->resolve( $engine->make_numeric( 1 / ( $_[0]->value ) ) );
    },
    sub {
      $d->reject(@_);
    }
  );

  return;
}

1;
