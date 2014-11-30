package Dallycot::AST::ForwardWalk;

# ABSTRACT: Find the value associated with a property of a subject

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub step {
  my ( $self, $engine, $root ) = @_;

  return $engine->execute( $self->[0] )->then(
    sub {
      my ($prop_name) = @_;
      my $prop = $prop_name->value;
      $root->fetch_property( $engine, $prop );
    }
  );
}

1;
