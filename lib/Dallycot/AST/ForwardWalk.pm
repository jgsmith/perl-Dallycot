package Dallycot::AST::ForwardWalk;

use strict;
use warnings;

use parent 'Dallycot::AST';

use Promises qw(deferred);

sub step {
  my($self, $engine, $root) = @_;

  my $d = deferred;

  $engine -> execute($self->[0]) -> done(sub {
    my($prop_name) = @_;
    my $prop = $prop_name -> value;
    $root -> fetch_property($engine, $d, $prop);
  }, sub {
    $d -> reject(@_);
  });

  return $d -> promise;
}

1;
