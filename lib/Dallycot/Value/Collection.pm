use strict;
use warnings;
package Dallycot::Value::Collection;

use parent 'Dallycot::Value::Any';

use Promises qw(deferred);

sub value { undef }

sub head {
  my $p = deferred;
  $p -> reject("head is not defined for " . ref($_[0]) . ".");
  $p -> promise;
}

sub tail {
  my $p = deferred;
  $p -> reject("tail is not defined for " . ref($_[0]) . ".");
  $p -> promise;
}

1;
