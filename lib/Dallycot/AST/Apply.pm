package Dallycot::AST::Apply;

# ABSTRACT: Apply bindings to lambda

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Promises qw(deferred);

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

sub simplify {
  my($self) = @_;

  return bless [
    $self->[$EXPRESSION]->simplify,
    [ map { $_ -> simplify } @{$self->[$BINDINGS] } ],
    $self->[$OPTIONS]
  ] => __PACKAGE__;
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
  my ( $self, $engine ) = @_;

  my $d = deferred;

  my $expr = $self->[$EXPRESSION];
  if($expr->isa('Dallycot::Value')) {
    $expr = bless [ $expr ] => 'Dallycot::AST::Identity';
  }

  $engine->execute( $expr )->done(
    sub {
      my ($lambda) = @_;
      if ( !$lambda ) {
        $d->reject("Undefined value can not be a function.");
      }
      elsif ( $lambda->can('apply') ) {
        my @bindings = @{$self->[$BINDINGS]};
        if(@bindings && $bindings[-1]->isa('Dallycot::AST::FullPlaceholder')) {
          pop @bindings;
          push @bindings, (bless [] => 'Dallycot::AST::Placeholder')x($lambda->min_arity - @bindings);
        }
        $lambda->apply(
          $engine,
          { %{ $self->[$OPTIONS] } },
          @bindings
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

  return $d->promise;
}

1;
