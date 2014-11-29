package Dallycot::AST::Apply;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Readonly;

Readonly my $EXPRESSION => 0;
Readonly my $BINDINGS   => 1;
Readonly my $OPTIONS    => 2;

sub new {
  my ( $class, $expression, $bindings, $options ) = @_;

  $class = ref $class || $class;
  $bindings //= [];
  $options  //= {};
  return bless [ $expression, $bindings, $options ] => $class;
}

sub child_nodes {
  my ($self) = @_;

  return $self->[$EXPRESSION], @{ $self->[$BINDINGS] || [] },
    values %{ $self->[$OPTIONS] || {} };
}

sub to_string {
  my ($self) = @_;

  return
      "("
    . $self->[$EXPRESSION]->to_string . ")("
    . join(
    ", ",
    ( map { $_->to_string } @{ $self->[$BINDINGS] } ),
    (
      map { $_ . " -> " . $self->[$OPTIONS]->{$_}->to_string }
      sort keys %{ $self->[$OPTIONS] }
    )
    ) . ")";
}

sub execute {
  my ( $self, $engine, $d ) = @_;

  $engine->execute( $self->[$EXPRESSION] )->done(
    sub {
      my ($lambda) = @_;
      if ( !$lambda ) {
        $d->reject("Undefined value can not be a function.");
      }
      elsif ( $lambda->can('apply') ) {
        $lambda->apply(
          $engine,
          { %{ $self->[$OPTIONS] } },
          @{ $self->[$BINDINGS] }
          )->done(
          sub {
            $d->resolve(@_);
          },
          sub {
            $d->reject(@_);
          }
          );
      }
      else {
        $d->reject( "Value of type "
            . $lambda->type
            . " can not be used as a function." );
      }
    },
    sub {
      $d->reject(@_);
    }
  );

  return;
}

1;
