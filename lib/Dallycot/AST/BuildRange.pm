package Dallycot::AST::BuildRange;

# ABSTRACT: Create open or closed range

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Promises qw(deferred);

sub execute {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  if ( @$self == 1 || !defined( $self->[1] ) ) {    # semi-open range
    $engine->execute( $self->[0] )->done(
      sub {
        $d->resolve( bless [@_] => 'Dallycot::Value::OpenRange' );
      },
      sub {
        $d->reject(@_);
      }
    );
  }
  else {
    $engine->collect(@$self)->done(
      sub {
        my ( $left_value, $right_value ) = @_;

        $left_value->is_less( $engine, $right_value )->done(
          sub {
            my ($f) = @_;

            $d->resolve(
              bless [ $left_value, $right_value, $f ? 1 : -1 ] =>
                'Dallycot::Value::ClosedRange' );
          },
          sub {
            $d->reject(@_);
          }
        );
      },
      sub {
        $d->reject(@_);
      }
    );
  }

  return $d->promise;
}

1;
