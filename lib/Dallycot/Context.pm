package Dallycot::Context;

# ABSTRACT: Execution context with value mappings and namespaces

use strict;
use warnings;

use utf8;
use Moose;
use Array::Utils qw(unique array_minus);

use Carp qw(croak cluck);

use experimental qw(switch);

#
# Contexts form a chain from the kernel on down
# The context for a statement has no parent, but is copied from the kernel's
#   context. Changes made are copied back to the kernel context info.
# Closures need to copy all of the info into a new context that is marked as
#   a closure.

has namespaces => ( is => 'ro', isa => 'HashRef', default => sub { +{} } );

has environment => ( is => 'ro', isa => 'HashRef', default => sub { +{} } );

has parent =>
  ( is => 'ro', isa => 'Dallycot::Context', predicate => 'has_parent' );

has is_closure => ( is => 'ro', isa => 'Bool', default => 0 );

sub add_namespace {
  my ( $self, $ns, $href ) = @_;

  if ( ( $self->is_closure || $self->has_parent )
    && defined( $self->namespaces->{$ns} ) )
  {
    croak
"Namespaces may not be defined multiple times in a sub-context or closure";
  }
  $self->namespaces->{$ns} = $href;

  return;
}

sub get_namespace {
  my ( $self, $ns ) = @_;

  if ( defined( $self->namespaces->{$ns} ) ) {
    return $self->namespaces->{$ns};
  }
  elsif ( $self->has_parent ) {
    return $self->parent->get_namespace($ns);
  }
}

sub has_namespace {
  my ( $self, $prefix ) = @_;

  return exists( $self->namespaces->{$prefix} )
    || $self->has_parent && $self->parent->has_namespace($prefix);
}

sub add_assignment {
  my ( $self, $identifier, $expr ) = @_;

  if ( ( $self->is_closure || $self->has_parent )
    && defined( $self->environment->{$identifier} ) )
  {
    croak "Identifiers may not be redefined in a sub-context or closure";
  }
  $self->environment->{$identifier} = $expr;
  return;
}

sub get_assignment {
  my ( $self, $identifier ) = @_;

  if ( defined( $self->environment->{$identifier} ) ) {
    return $self->environment->{$identifier};
  }
  elsif ( $self->has_parent ) {
    return $self->parent->get_assignment($identifier);
  }
}

sub has_assignment {
  my ( $self, $identifier ) = @_;

  return exists( $self->environment->{$identifier} )
    || $self->has_parent && $self->parent->has_assignment($identifier);
}

sub make_closure {
  my ( $self, $node ) = @_;

  my ( %namespaces, %environment );

  # we only copy the values we can use
  my @stack       = ($node);
  my @identifiers = ();

  while (@stack) {
    $node = shift @stack;
    if ( !ref $node ) {
      cluck "We have a non-ref node! ($node)";
    }

    push @stack, $node->child_nodes;

    my @ids = $node->identifiers;
    if (@ids) {
      my @new_ids = array_minus( @ids, @identifiers );

      #push @stack, grep { ref } map { $self->get_assignment($_) } @new_ids;
      push @identifiers, @new_ids;
    }
  }

  @identifiers = unique @identifiers;

  for my $identifier (@identifiers) {
    if ( 'ARRAY' eq ref $identifier ) {
      if ( !defined( $namespaces{ $identifier->[0] } ) ) {
        $namespaces{ $identifier->[0] } =
          $self->get_namespace( $identifier->[0] );
      }
    }
    elsif ( $identifier !~ /^#/ && !defined( $environment{$identifier} ) ) {
      my $value = $self->get_assignment($identifier);
      $environment{$identifier} = $value if defined $value;
    }
  }

# making the closure a child/parent allows setting overrides once in the closure code
  return $self->new(
    namespaces  => \%namespaces,
    environment => \%environment,
  );
}

1;
