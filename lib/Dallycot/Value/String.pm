package Dallycot::Value::String;

use parent 'Dallycot::Value::Any';

use Promises qw(deferred);

sub new {
  bless [ $_[1], $_[2] || 'en' ] => __PACKAGE__;
}

sub lang { shift->[1] }

sub id {
  my($self) = @_;

  $self->[0] . "@" . $self->[1] . "^^String";
}

sub length {
  my($self, $engine, $d) = @_;

  $d -> resolve($engine->Numeric(CORE::length $self->[0]));
}

sub take_range {
  my($self, $engine, $offset, $length) = @_;

  my $d = deferred;

  if(abs($offset) > CORE::length($self->[0])) {
    $d -> resolve($self -> new('', $self->lang));
  }
  else {
    $d -> resolve($self -> new(substr($self->value, $offset-1, $length - $offset + 1), $self->lang));
  }

  $d -> promise;
}

sub drop {
  my($self, $engine, $offset) = @_;

  my $d = deferred;

  if(abs($offset) > CORE::length($self->value)) {
    $d -> resolve($self -> new('', $self->lang));
  }
  else {
    $d -> resolve($self -> new(
      substr($self -> value, $offset),
      $self -> lang
    ));
  }

  $d -> promise;
}

sub value_at {
  my($self, $engine, $index) = @_;

  my $d = deferred;

  if(!$index || abs($index) > CORE::length($self -> [0])) {
    $d -> resolve($self -> new('', $self -> [1]));
  }
  else {
    $d -> resolve($self->new(substr($self->[0], $index-1, 1), $self->[1]));
  }

  $d -> promise;
}

sub is_equal {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve(
    $self->lang eq $other->lang
    && $self->value eq $other->value
  );
}

sub is_less {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve(
    $self->lang lt $other->lang
    || $self->lang eq $other->lang
       && $self->value lt $other->value
  );
}

sub is_less_or_equal {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve(
    $self->lang lt $other->lang
    || $self->lang eq $other->lang
       && $self->value le $other->value
  );
}

sub is_greater {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve(
    $self->lang gt $other->lang
    || $self->lang eq $other->lang
       && $self->value gt $other->value
  );
}

sub is_greater_or_equal {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve(
    $self->lang gt $other->lang
    || $self->lang eq $other->lang
       && $self->value ge $other->value
  );
}

1;
