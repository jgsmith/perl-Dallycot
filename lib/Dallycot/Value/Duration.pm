package Dallycot::Value::Duration;

# ABSTRACT: Date and time values

use strict;
use warnings;

use utf8;
use parent 'Dallycot::Value::Any';

use DateTime;

use Scalar::Util qw(blessed);

use Promises qw(deferred);

sub new {
  my($class, %options) = @_;

  $class = ref $class || $class;

  for my $k (keys %options) {
    $options{$k} = $options{$k} -> value -> numify if blessed($options{$k}) && $options{$k}->isa('Dallycot::Value::Numeric');
  }

  my $duration_class = delete $options{'class'};
  $duration_class //= 'DateTime::Duration';

  if($options{object}) {
    return bless [
      $duration_class->from_object(object => $options{object})
    ] => $class;
  }
  else {
    return bless [
      $duration_class->new(
        map { $_ => $options{$_} } grep { $options{$_} } keys %options
      )
    ] => $class;
  }
}

sub to_rdf {
  my($self, $model) = @_;

  # we need to record the date/time as represented in RDF, but might want to
  # record the calendar type as well
  my $literal = RDF::Trine::Node::Literal->new(
    $self -> as_text,
    '',
    $model -> meta_uri('xsd:duration')
  );

  return $literal;
}

sub as_text {
  my($self) = @_;

  if($self -> [0] -> is_zero) {
    return 'P0Y';
  }

  my %amounts;

  my $duration = $self -> [0];
  my $string = '';
  if($duration -> is_negative) {
    $duration = $duration -> clone -> inverse;
    $string = '-';
  }
  $string .= 'P';

  @amounts{qw(Y M D h m s)} = $duration -> in_units('years', 'months', 'days', 'hours', 'minutes', 'seconds');

  my $days = join("",
    map { $_ . $amounts{$_} }
    grep { $amounts{$_} > 0 }
    qw(Y M D)
  );

  my $hours = join("",
    map { upcase($_) . $amounts{$_} }
    grep { $amounts{$_} > 0 }
    qw(h m s)
  );

  $string .= $days;

  $string .= 'T' . $hours if $hours ne '';

  return $string;
}

sub value {
  my($self) = @_;

  return $self->[0];
}

sub negated {
  my($self) = @_;

  return $self->new( $self->[0] -> inverse );
}

sub is_equal {
  my ( $self, $engine, $other ) = @_;

  my $d = deferred;

  $d->resolve( 0 == DateTime::Duration->compare( $self->value, $other->value ) );

  return $d->promise;
}

sub is_less {
  my ( $self, $engine, $other ) = @_;

  my $d = deferred;

  $d->resolve( 0 > DateTime::Duration->compare( $self->value, $other->value ) );

  return $d->promise;
}

sub is_less_or_equal {
  my ( $self, $engine, $other ) = @_;

  my $d = deferred;

  $d->resolve( 0 >= DateTime::Duration->compare( $self->value, $other->value ) );

  return $d->promise;
}

sub is_greater {
  my ( $self, $engine, $other ) = @_;

  my $d = deferred;

  $d->resolve( 0 < DateTime::Duration->compare( $self->value, $other->value ) );

  return $d->promise;
}

sub is_greater_or_equal {
  my ( $self, $engine, $other ) = @_;

  my $d = deferred;

  $d->resolve( 0 <= DateTime::Duration->compare( $self->value, $other->value ) );

  return $d->promise;
}


1;
