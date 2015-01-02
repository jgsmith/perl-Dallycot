package Dallycot::Value::EmptyStream;

# ABSTRACT: A stream with no values

use strict;
use warnings;

use utf8;
use parent 'Dallycot::Value::Collection';

use Promises qw(deferred);

our $INSTANCE;

sub new {
  return $INSTANCE ||= bless [] => __PACKAGE__;
}

sub prepend {
  my($self, @things) = @_;

  my $stream = Dallycot::Value::Stream->new(shift @things);
  foreach my $thing (@things) {
    $stream = Dallycot::Value::Stream->new($thing, $stream);
  }
  return $stream;
}

sub as_text { return "[ ]" }

sub is_defined { return 0 }

sub calculate_length {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  $d->resolve( $engine->make_numeric(0) );

  return $d->promise;
}

sub calculate_reverse {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  $d->resolve($self);

  return $d->promise;
}

sub apply_map {
  my ( $self, $engine, $d, $transform ) = @_;

  $d->resolve($self);

  return;
}

sub value_at {
  my $p = deferred;

  $p->resolve( Dallycot::Value::Undefined->new );

  return $p->promise;
}

sub head {
  my $p = deferred;

  $p->resolve( Dallycot::Value::Undefined->new );

  return $p->promise;
}

sub tail {
  my ($self) = @_;

  my $p = deferred;

  $p->resolve($self);

  return $p->promise;
}

sub reduce {
  my ( $self, $engine, $start, $lambda ) = @_;

  my $p = deferred;

  $p->resolve($start);

  return $p->promise;
}

1;
