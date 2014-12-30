package Dallycot::Value::URI;

# ABSTRACT: A URI value that can be dereferenced

use strict;
use warnings;

use utf8;
use parent 'Dallycot::Value::Any';

use Promises qw(deferred);
use Scalar::Util qw(blessed);

use experimental qw(switch);

sub new {
  my ( $class, $uri ) = @_;

  $class = ref $class || $class;

  $uri = URI->new($uri)->canonical->as_string;

  return bless [$uri] => $class;
}

sub calculate_length {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  $d->resolve( $engine->make_numeric( length $self->[0] ) );

  return $d->promise;
}

sub value_at {
  my ( $self, $engine, $index ) = @_;

  my $d = deferred;

  $d->resolve(
    bless [ substr( $self->[0], $index - 1, 1 ), 'en' ] =>
      'Dallycot::Value::String' );

  return $d->promise;
}

sub is_lambda {
  my( $self ) = @_;

  my($lib, $method) = $self->_get_library_and_method;

  return unless defined $lib;
  my $def = $lib -> get_assignment($method);
  return unless blessed($def);
  return 1 if $def->isa(__PACKAGE__);
  return $def -> is_lambda;
}

sub min_arity {
  my( $self ) = @_;

  my($lib, $method) = $self->_get_library_and_method;
  if($lib) {
    return $lib -> min_arity($method);
  }
  else {
    return 0; # TODO: fix once we fetch remote libraries
  }
}

sub _get_library_and_method {
  my($self) = @_;
  
  my($namespace, $method) = split(/#/, $self->[0], 2);
  if(!defined $method) {
    if($self -> [0] =~ m{^(.*/)(.+?)$}x) {
      $namespace = $1;
      $method = $2;
    }
    else {
      $namespace = $self -> [0];
      $method = '';
    }
  }
  else {
    $namespace .= '#';
  }

  my $registry = Dallycot::Registry->instance;

  if($registry->has_namespace($namespace)) {
    return ($registry->namespaces->{$namespace}, $method);
  }
  return;
}

sub apply {
  my( $self, $engine, $options, @bindings ) = @_;

  my($lib, $method) = $self->_get_library_and_method;

  if($lib) {
    return $lib -> apply($method, $engine, $options, @bindings);
  }
  else { # TODO: fetch resource and see if it's a lambda
    my $d = deferred;
    $d -> reject($self->[0] . " is not a lambda");
    return $d -> promise;
  }
}

sub execute {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  my $url = $self->[0];

  my $resolver = Dallycot::Resolver->instance;
  $resolver->get($url)->done(
    sub {
      $d->resolve(@_);
    },
    sub {
      $d->reject(@_);
    }
  );

  return $d->promise;
}

1;
