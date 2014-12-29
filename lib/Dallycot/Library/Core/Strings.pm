package Dallycot::Library::Core::Strings;

# ABSTRACT: Core library of useful string functions

use strict;
use warnings;

use utf8;

use Dallycot::Library;

use experimental qw(switch);

use Promises qw(deferred);

ns 'https://www.dallycot.io/ns/strings/1.0#';

#====================================================================
#
# Basic string functions

define 'string-take' => (
  hold => 0,
  arity => 2,
  options => {}
), sub {
  my ( $engine, $options, $string, $spec ) = @_;

  if ( !$string ) {
    my $d = deferred;
    $d->resolve( $engine->UNDEFINED );
    return $d -> promise;
  }
  elsif ( !$spec ) {
    my $d = deferred;
    $d->resolve( $engine->UNDEFINED );
    return $d -> promise;
  }
  else {
    if ( $spec->isa('Dallycot::Value::Numeric') ) {
      my $length = $spec->value->numify;
      return $string->take_range( $engine, 1, $length );
    }
    elsif ( $spec->isa('Dallycot::Value::Vector') ) {
      given ( scalar(@$spec) ) {
        when (1) {
          if ( $spec->[0]->isa('Dallycot::Value::Numeric') ) {
            my $offset = $spec->[0]->value->numify;
            return $string->value_at( $engine, $offset );
          }
          else {
            my $d = deferred;
            $d->reject("Offset must be numeric");
            return $d -> promise;
          }
        }
        when (2) {
          if ( $spec->[0]->isa('Dallycot::Value::Numeric')
            && $spec->[1]->isa('Dallycot::Value::Numeric') )
          {
            my ( $offset, $length ) =
              ( $spec->[0]->value->numify, $spec->[1]->value->numify );

            return $string->take_range( $engine, $offset, $length );
          }
          else {
            my $d = deferred;
            $d->reject("string-take requires numeric offsets");
            return $d -> promise;
          }
        }
        default {
          my $d = deferred;
          $d->reject(
            "string-take requires 1 or 2 numeric elements in an offset vector"
          );
          return $d->promise;
        }
      }
    }
    else {
      my $d = deferred;
      $d->reject("Offset must be numeric or a vector of numerics");
      return $d->promise;
    }
  }
};

define 'string-drop' => (
  hold => 0,
  arity => 2,
  options => {},
), sub {
  my ( $engine, $options, $string, $spec ) = @_;

  if ( !$string ) {
    my $d = deferred;
    $d->resolve( $engine->UNDEFINED );
    return $d -> promise;
  }
  elsif ( !$spec ) {
    my $d = deferred;
    $d->resolve( $engine->UNDEFINED );
    return $d -> promise;
  }
  elsif ( $spec->isa('Dallycot::Value::Numeric') ) {
    my $offset = $spec->value->numify;
    return $string->drop( $engine, $offset );
  }
  else {
    my $d = deferred;
    $d->reject("string-drop requires a numeric second argument");
    return $d -> promise;
  }
};

1;
