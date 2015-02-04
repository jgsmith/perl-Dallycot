package Dallycot::AST::BuildSet;

# ABSTRACT: Create set value

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub execute {
  my ( $self, $engine ) = @_;

  return $engine->collect(@$self)->then(
    sub {
      return Dallycot::Value::Set->new(@_);
    }
  );
}

1;
