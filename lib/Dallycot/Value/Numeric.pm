use strict;
use warnings;
package Dallycot::Value::Numeric;

use parent 'Dallycot::Value::Any';

use Promises qw(deferred);

sub new {
  bless [ ref($_[1]) ? $_[1] : Math::BigRat->new($_[1]) ] => __PACKAGE__;
}

sub id {
  shift -> [0] -> bstr . "^^Numeric";
}

sub value {
  shift -> [0]
}

sub length {
  my($self, $engine, $d) = @_;

  $d -> resolve($self -> new( $self->[0]->copy->bfloor->length ));
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

sub successor {
  my($self) = @_;

  my $d = deferred;

  $d -> resolve(bless [ $self->[0]->copy->binc ] => __PACKAGE__);

  $d -> promise;
}

sub predecessor {
  my($self) = @_;

  my $d = deferred;

  $d -> resolve(bless [ $self->[0]->copy->bdec ] => __PACKAGE__);
}

1;
