package Dallycot::AST::Fetch;

# ABSTRACT: Find the value associated with an identifier

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Dallycot::Util qw(maybe_promise);
use Promises       qw(deferred);

sub new {
  my ( $class, $identifier ) = @_;

  $class = ref $class || $class;

  return bless [$identifier] => $class;
}

sub identifiers {
  my ($self) = @_;

  if ( @{$self} == 1 ) {
    return $self->[0];
  }
  else {
    return [ @{$self} ];
  }
}

sub to_string {
  my ($self) = @_;

  return $self->[0];
}

sub execute {
  my ( $self, $engine ) = @_;

  my $registry = Dallycot::Registry->instance;
  if ( @$self > 1 ) {
    if ( $engine->has_namespace( $self->[0] ) ) {
      my $ns = $engine->get_namespace( $self->[0] );
      if ( $registry->has_namespace($ns) ) {
        if ( $registry->has_assignment( $ns, $self->[1] ) ) {
          return maybe_promise($registry->get_assignment( $ns, $self->[1] ));
        }
        else {
          my $d = deferred;
          $d->reject( join( ":", @$self ) . " is undefined." );
          return $d -> promise;
        }
      }
      else {
        my $d = deferred;
        $d->reject("The namespace \"$ns\" is unregistered.");
        return $d -> promise;
      }
    }
    else {
      my $d = deferred;
      $d->reject("The namespace prefix \"@{[$self->[0]]}\" is undefined.");
      return $d -> promise;
    }
  }
  elsif ( $registry->has_assignment( $engine -> get_namespace_search_path, $self->[0] ) ) {
    return maybe_promise($registry->get_assignment( $engine -> get_namespace_search_path, $self->[0] ));
  }
  elsif ( $engine->has_assignment( $self->[0] ) ) {
    return maybe_promise($engine->get_assignment( $self->[0] ));
  }
  else {
    my $d = deferred;
    $d->reject( $self->[0] . " is undefined." );
    return $d -> promise;
  }
}

1;
