package Dallycot::Value::Any;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::Value';

use Promises qw(deferred);

sub value {
  my($self) = @_;

  return $self->[0];
}

sub is_defined { return 1 }

sub successor {
  my($self) = @_;

  my $d = deferred;

  $d -> reject($self->type . " has no successor");

  return $d -> promise;
}

sub predecessor {
  my($self) = @_;

  my $d = deferred;

  $d -> reject($self->type . " has no predecessor");

  return $d -> promise;
}

sub to_string {
  my($self) = @_;
  return $self -> id;
}

1;
