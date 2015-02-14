package Dallycot::AST::BuildRange;

# ABSTRACT: Create open or closed range

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub execute {
  my ( $self, $engine ) = @_;

  if ( @$self == 1 || !defined( $self->[1] ) ) {    # semi-open range
    return $engine->execute( $self->[0] )->then(
      sub {
        bless [@_] => 'Dallycot::Value::OpenRange';
      }
    );
  }
  else {
    return $engine->collect(@$self)->then(
      sub {
        my ( $left_value, $right_value ) = @_;

        $left_value->is_less( $engine, $right_value )->then(
          sub {
            my ($f) = @_;

            bless [ $left_value, $right_value, $f ? 1 : -1 ] => 'Dallycot::Value::ClosedRange';
          }
        );
      }
    );
  }
}

1;
