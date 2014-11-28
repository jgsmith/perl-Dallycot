use strict;
use warnings;
package Dallycot::Value::Any;

use parent 'Dallycot::Value';

use Promises qw(deferred);

sub value { $_[0][0] }

sub is_defined { 1 }

sub successor {
  my($self) = @_;

  my $d = deferred;

  $d -> reject($self->type . " has no successor");

  $d -> promise;
}

sub predecessor {
  my($self) = @_;

  my $d = deferred;

  $d -> reject($self->type . " has no predecessor");

  $d -> promise;
}

sub to_string { shift -> id }

1;
