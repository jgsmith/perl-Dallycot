package Dallycot::Value::Undefined;

use parent 'Dallycot::Value::Any';

sub new { bless [] => __PACKAGE__ }

sub value { undef }

sub id { '^^Undefined' }

sub is_defined { 0 }

sub is_equal {
  my($self, $engine, $promise, $other) = @_;

  if(UNIVERSAL::isa($other, __PACKAGE__)) {
    $promise -> resolve($engine->TRUE);
  }
  else {
    $promise -> resolve($engine->FALSE);
  }
}

*is_less_or_equal = \&is_equal;
*is_greater_or_equal = \&is_equal;

sub is_less {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve($engine->FALSE);
}

*is_greater = \&is_less;

1;
