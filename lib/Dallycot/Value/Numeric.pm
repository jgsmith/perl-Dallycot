package Dallycot::Value::Numeric;

use strict;
use warnings;

use parent 'Dallycot::Value::Any';

use Promises qw(deferred);

sub new {
  my($class, $value) = @_;

  $class = ref $class || $class;

  return bless [
    ref($value) ? $value : Math::BigRat->new($value)
  ] => $class;
}

sub id {
  my($self) = @_;
  return $self -> [0] -> bstr . "^^Numeric";
}

sub value {
  my($self) = @_;
  return $self -> [0]
}

sub calculate_length {
  my($self, $engine) = @_;

  my $d = deferred;

  $d -> resolve($self -> new( $self->[0]->copy->bfloor->length ));

  return $d -> promise;
}

sub is_equal {
  my($self, $engine, $other) = @_;

  my $d = deferred;

  $d -> resolve($self->value == $other->value);

  return $d -> promise;
}

sub is_less {
  my($self, $engine, $other) = @_;

  my $d = deferred;

  $d -> resolve($self->value < $other->value);

  return $d -> promise;
}

sub is_less_or_equal {
  my($self, $engine, $other) = @_;

  my $d = deferred;

  $d -> resolve($self->value <= $other->value);

  return $d -> promise;
}

sub is_greater {
  my($self, $engine, $other) = @_;

  my $d = deferred;

  $d -> resolve($self->value > $other->value);

  return $d -> promise;
}

sub is_greater_or_equal {
  my($self, $engine, $other) = @_;

  my $d = deferred;

  $d -> resolve($self->value >= $other->value);

  return $d -> promise;
}

sub successor {
  my($self) = @_;

  my $d = deferred;

  $d -> resolve($self -> new($self->[0]->copy->binc));

  return $d -> promise;
}

sub predecessor {
  my($self) = @_;

  my $d = deferred;

  $d -> resolve($self -> new($self->[0]->copy->bdec));

  return $d -> promise;
}

1;
