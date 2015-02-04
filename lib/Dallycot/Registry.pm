package Dallycot::Registry;

# ABSTRACT: Manage namespace handler mappings

use strict;
use warnings;

use utf8;
use MooseX::Singleton;
use MooseX::Types::Moose qw(ArrayRef);
use Promises qw(collect deferred);

has type_handlers => (
  is      => 'ro',
  isa     => 'HashRef',
  default => sub { +{} }
);

has namespaces => (
  is      => 'ro',
  isa     => 'HashRef',
  default => sub { +{} }
);

has _namespace_promises => (
  is      => 'ro',
  isa     => 'HashRef',
  default => sub { +{} }
);

sub register_used_namespaces {
  my ( $self, @uris ) = @_;

  for my $ns (@uris) {
    $self->_namespace_promises->{$ns} ||= deferred;
  }
  return collect( map { $self->_namespace_promises->{$_}->promise } @uris );
}

sub has_assignment {
  my ( $self, $ns, $symbol ) = @_;

  if ( is_ArrayRef($ns) ) {
    foreach my $n (@$ns) {
      return 1
        if $self->namespaces->{$n}
        && $self->namespaces->{$n}->has_assignment($symbol);
    }
    return;
  }

  return $self->namespaces->{$ns}
    && $self->namespaces->{$ns}->has_assignment($symbol);
}

sub get_assignment {
  my ( $self, $namespace, $symbol ) = @_;

  if ( is_ArrayRef($namespace) ) {
    foreach my $n (@$namespace) {
      if ( $self->has_assignment( $n, $symbol ) ) {
        return $self->get_assignment( $n, $symbol );
      }
    }
    return;
  }

  if ( $self->namespaces->{$namespace} ) {
    my $ns = $self->namespaces->{$namespace};
    if ( $ns->has_assignment($symbol) ) {
      return $ns->get_assignment($symbol);
    }
  }

  return;
}

sub has_namespace {
  my ( $self, $ns ) = @_;

  return exists $self->namespaces->{$ns} && defined $self->namespaces->{$ns};
}

sub register_namespace {
  my ( $self, $ns, $context ) = @_;

  if ( !$self->has_namespace($ns) ) {
    $self->namespaces->{$ns} = $context;
  }

  $self->_namespace_promises->{$ns} ||= deferred;
  $self->_namespace_promises->{$ns}->resolve();

  return;
}

sub initialize {
  my $self = shift;

  $self->SUPER::initialize(@_);

  for my $type ( Dallycot::Value->types ) {
    $self->type_handlers->{ $type->type } = $type;
  }

  return $self;
}

1;
