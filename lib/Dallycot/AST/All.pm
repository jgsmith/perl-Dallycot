package Dallycot::AST::All;

# ABSTRACT: Return true iff all expressions evaluate true

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST::LoopBase';

sub new {
  my ( $class, @exprs ) = @_;

  $class = ref $class || $class;
  return bless \@exprs => $class;
}

sub simplify {
  my ($self) = @_;

  return bless [ map { $_->simplify } @$self ] => __PACKAGE__;
}

sub process_loop {
  my ( $self, $engine, $d, @expressions ) = @_;

  if ( !@expressions ) {
    $d->resolve( $engine->TRUE );
  }
  else {
    $engine->execute( shift @expressions, ['Boolean'] )->done(
      sub {
        if ( $_[0]->value ) {
          $self->process_loop( $engine, $d, @expressions );
        }
        else {
          $d->resolve( $engine->FALSE );
        }
      },
      sub {
        $d->reject(@_);
      }
    );
  }

  return;
}

1;
