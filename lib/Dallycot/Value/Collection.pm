package Dallycot::Value::Collection;

# ABSTRACT: Base class for streams, vectors, sets, etc.

use strict;
use warnings;

use utf8;
use parent 'Dallycot::Value::Any';

use Promises qw(deferred);

use Scalar::Util qw(blessed);

sub value { }

sub calculate_length {
  my ( $self, $engine ) = @_;
  my $d = deferred;

  $d->resolve( $engine->make_numeric( Math::BigRat->binf() ) );

  return $d->promise;
}

sub head {
  my ($self) = @_;
  my $p = deferred;
  $p->reject( "head is not defined for " . blessed($self) . "." );
  return $p->promise;
}

sub tail {
  my ($self) = @_;
  my $p = deferred;
  $p->reject( "tail is not defined for " . blessed($self) . "." );
  return $p->promise;
}

1;
