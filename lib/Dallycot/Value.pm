package Dallycot::Value;

use strict;
use warnings;

use utf8;
use Carp qw(croak);

use Module::Pluggable
  require     => 1,
  sub_name    => '_types',
  search_path => 'Dallycot::Value';

use Promises qw(deferred);

our @TYPES;

sub types {
  return @TYPES = @TYPES || shift->_types;
}

__PACKAGE__->types;

sub type {
  my ($self) = @_;

  my $type = ref $self;

  return substr( $type, CORE::length(__PACKAGE__) + 2 );
}

sub simplify {
  my ($self) = @_;

  return $self;
}

sub to_json {
  my ($self) = @_;

  croak "to_json not defined for " . ( blessed($self) || $self );
}

sub to_string {
  my ($self) = @_;

  croak "to_string not defined for " . ( blessed($self) || $self );
}

sub child_nodes { return () }

sub identifiers { return () }

sub calculate_length {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  $d->resolve( $engine->ZERO );

  return $d->promise;
}

sub execute {
  my ( $self, $engine, $d ) = @_;

  $d->resolve($self);

  return;
}

1;
