package Dallycot::Value::String;

# ABSTRACT: A string with an associated language

use strict;
use warnings;

use utf8;
use parent 'Dallycot::Value::Any';

use Promises qw(deferred);

sub new {
  my ( $class, $value, $lang ) = @_;

  $class = ref $class || $class;

  return bless [ $value // '', $lang // 'en' ] => $class;
}

sub lang { return shift->[1] }

sub id {
  my ($self) = @_;

  return $self->[0] . "@" . $self->[1] . "^^String";
}

sub as_text {
  my($self) = @_;

  my $val = $self -> value;
  $val =~ s{\\}{\\\\}g;
  $val =~ s{\n}{\\n}g;
  $val =~ s{"}{\\"}g;
  if($self->[1] eq 'en') {
    return qq{"$val"};
  }
  else {
    return qq{"$val"\@}.$self->[1];
  }
}

sub prepend {
  my($self, @things) = @_;

  return __PACKAGE__ -> new(
    join("", (map {
      $_ -> value
    } reverse @things), $self -> value)
  );
}

sub calculate_length {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  $d->resolve( $engine->make_numeric( CORE::length $self->[0] ) );

  return $d->promise;
}

sub calculate_reverse {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  $d->resolve( $self->new( reverse( $self->value ), $self->lang ) );

  return $d->promise;
}

sub take_range {
  my ( $self, $engine, $offset, $length ) = @_;

  my $d = deferred;

  if ( abs($offset) > length( $self->[0] ) ) {
    $d->resolve( $self->new( '', $self->lang ) );
  }
  else {
    $d->resolve(
      $self->new(
        substr( $self->value, $offset - 1, $length - $offset + 1 ),
        $self->lang
      )
    );
  }

  return $d->promise;
}

sub drop {
  my ( $self, $engine, $offset ) = @_;

  my $d = deferred;

  if ( abs($offset) > length( $self->value ) ) {
    $d->resolve( $self->new( '', $self->lang ) );
  }
  else {
    $d->resolve( $self->new( substr( $self->value, $offset ), $self->lang ) );
  }

  return $d->promise;
}

sub value_at {
  my ( $self, $engine, $index ) = @_;

  my $d = deferred;

  if ( !$index || abs($index) > length( $self->[0] ) ) {
    $d->resolve( $self->new( '', $self->[1] ) );
  }
  else {
    $d->resolve(
      $self->new( substr( $self->[0], $index - 1, 1 ), $self->[1] ) );
  }

  return $d->promise;
}

sub is_equal {
  my ( $self, $engine, $other ) = @_;

  my $d = deferred;

  $d->resolve( $self->lang eq $other->lang && $self->value eq $other->value );

  return $d->promise;
}

sub is_less {
  my ( $self, $engine, $other ) = @_;

  my $d = deferred;

  $d->resolve( $self->lang lt $other->lang
      || $self->lang eq $other->lang && $self->value lt $other->value );

  return $d->promise;
}

sub is_less_or_equal {
  my ( $self, $engine, $other ) = @_;

  my $d = deferred;

  $d->resolve( $self->lang lt $other->lang
      || $self->lang eq $other->lang && $self->value le $other->value );

  return $d->promise;
}

sub is_greater {
  my ( $self, $engine, $other ) = @_;

  my $d = deferred;

  $d->resolve( $self->lang gt $other->lang
      || $self->lang eq $other->lang && $self->value gt $other->value );

  return $d->promise;
}

sub is_greater_or_equal {
  my ( $self, $engine, $other ) = @_;

  my $d = deferred;

  $d->resolve( $self->lang gt $other->lang
      || $self->lang eq $other->lang && $self->value ge $other->value );

  return $d->promise;
}

1;
