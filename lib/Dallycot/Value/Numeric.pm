package Dallycot::Value::Numeric;

# ABSTRACT: An arbitrary precision numeric value

use strict;
use warnings;

use utf8;
use parent 'Dallycot::Value::Any';

use Promises qw(deferred);

sub new {
  my ( $class, $value ) = @_;

  $class = ref $class || $class;

  return bless [ ref($value) ? $value : Math::BigRat->new($value) ] => $class;
}

sub id {
  my ($self) = @_;
  return $self->[0]->bstr . "^^Numeric";
}

sub is_defined { return 1 }

sub is_empty { return }

sub as_text {
  my($self) = @_;

  return $self->[0]->bstr;
}

sub value {
  my ($self) = @_;
  return $self->[0];
}

sub calculate_length {
  my ( $self, $engine ) = @_;

  return $self->new( $self->[0]->copy->bfloor->length );
}

sub is_equal {
  my ( $self, $engine, $other ) = @_;

  my $d = deferred;

  $d->resolve( $self->value == $other->value );

  return $d->promise;
}

sub is_less {
  my ( $self, $engine, $other ) = @_;

  my $d = deferred;

  $d->resolve( $self->value < $other->value );

  return $d->promise;
}

sub is_less_or_equal {
  my ( $self, $engine, $other ) = @_;

  my $d = deferred;

  $d->resolve( $self->value <= $other->value );

  return $d->promise;
}

sub is_greater {
  my ( $self, $engine, $other ) = @_;

  my $d = deferred;

  $d->resolve( $self->value > $other->value );

  return $d->promise;
}

sub is_greater_or_equal {
  my ( $self, $engine, $other ) = @_;

  my $d = deferred;

  $d->resolve( $self->value >= $other->value );

  return $d->promise;
}

sub successor {
  my ($self) = @_;

  my $d = deferred;

  $d->resolve( $self->new( $self->[0]->copy->binc ) );

  return $d->promise;
}

sub predecessor {
  my ($self) = @_;

  my $d = deferred;

  $d->resolve( $self->new( $self->[0]->copy->bdec ) );

  return $d->promise;
}

1;
