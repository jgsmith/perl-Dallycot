package Dallycot::Value::Boolean;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::Value::Any';

use Promises qw(deferred);

use Readonly;

Readonly my $TRUE => bless [ !!1 ] => __PACKAGE__;
Readonly my $FALSE => bless [ !!0 ] => __PACKAGE__;

sub new {
  my($class, $f) = @_;

  return $f ? $TRUE : $FALSE;
}

sub id {
  if(shift->value) {
    return "true^^Boolean";
  }
  else {
    return "false^^Boolean";
  }
}

sub calculate_length {
  my($self, $engine) = @_;

  my $d = deferred;

  $d -> resolve($engine->make_numeric(1));

  return $d -> promise;
}

sub is_equal {
  my($self, $engine, $other) = @_;

  my $d = deferred;

  $d -> resolve($self->value == $other->value);

  return $d;
}

sub is_less {
  my($self, $engine, $other) = @_;

  my $d = deferred;

  $d -> resolve($self->value < $other->value);

  return $d;
}

sub is_less_or_equal {
  my($self, $engine, $other) = @_;

  my $d = deferred;

  $d -> resolve($self->value <= $other->value);

  return $d;
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

  return $d;
}

1;
