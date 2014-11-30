package Dallycot::AST::Defined;

# ABSTRACT: Test if expression evaluates to a defined value

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Scalar::Util qw(blessed);

sub to_string {
  my ($self) = @_;

  return "?(" . ( $self->[0]->to_string ) . ")";
}

sub execute {
  my ( $self, $engine ) = @_;

  return $engine->execute( $self->[0] )->then(
    sub {
      my ($result) = @_;
      if ( blessed $result ) {
        return ( $result->is_defined ? $engine->TRUE : $engine->FALSE );
      }
      else {
        return ( $engine->FALSE );
      }
    }
  );
}

1;
