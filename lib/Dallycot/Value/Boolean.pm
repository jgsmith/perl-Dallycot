use strict;
use warnings;
package Dallycot::Value::Boolean;

use parent 'Dallycot::Value::Any';

sub new {
  bless [ !!$_[1] ] => __PACKAGE__;
}

sub id {
  if(shift->value) {
    "true^^Boolean";
  }
  else {
    "false^^Boolean";
  }
}

sub length {
  my($self, $engine, $d) = @_;

  $d -> resolve($engine->make_numeric(1));
}

sub is_equal {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve($self->value == $other->value);
}

sub is_less {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve($self->value < $other->value);
}

sub is_less_or_equal {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve($self->value <= $other->value);
}

sub is_greater {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve($self->value > $other->value);
}

sub is_greater_or_equal {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve($self->value >= $other->value);
}

1;
