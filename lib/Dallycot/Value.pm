package Dallycot::Value;

use strict;
use warnings;

use Carp qw(croak);

use Module::Pluggable require => 1, sub_name => '_types', search_path => 'Dallycot::Value';

our @TYPES;

sub types {
  @TYPES = @TYPES || shift -> _types;
}

__PACKAGE__ -> types;

sub type {
  my($self) = @_;

  my $type = ref $self;

  substr($type, CORE::length(__PACKAGE__)+2);
}

sub simplify { shift }

sub to_json { croak "to_json not defined for " . (ref($_[0]) || $_[0]); }

sub to_string { croak "to_string not defined for ". (ref($_[0]) || $_[0]); }

sub child_nodes { () }

sub identifiers { () }

sub length {
  my($self, $engine, $d) = @_;

  $d -> resolve($engine -> Numeric(0));
}

sub execute {
  my($self, $engine, $d) = @_;

  $d->resolve($self);
}

1;
