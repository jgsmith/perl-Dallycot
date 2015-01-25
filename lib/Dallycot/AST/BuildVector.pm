package Dallycot::AST::BuildVector;

# ABSTRACT: Create vector value

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub execute {
  my ( $self, $engine ) = @_;

  return $engine->collect(@$self)->then(
    sub {
      my (@bits) = @_;

      bless \@bits => 'Dallycot::Value::Vector';
    }
  );
}

1;
