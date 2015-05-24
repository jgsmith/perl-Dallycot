package Dallycot::Library::Core::DateTime;

# ABSTRACT: Core library of useful date/time functions

use strict;
use warnings;

use utf8;

use Dallycot::Library;

use experimental qw(switch);

use Carp qw(croak);
use DateTime;
use DateTime::Calendar::Mayan;
use DateTime::Calendar::Hebrew;
use DateTime::Calendar::Julian;
use DateTime::Calendar::Pataphysical;
use DateTime::Calendar::Hijri;

use DateTime::Format::Flexible;
use List::Util qw(all any);
use Promises qw(deferred);

use Dallycot::Library::Core          ();

use Dallycot::Value::DateTime;
use Dallycot::Value::Duration;

ns 'http://www.dallycot.net/ns/date-time/1.0#';

# uses 'http://www.dallycot.net/ns/loc/1.0#',
#      'http://www.dallycot.net/ns/core/1.0#';

#====================================================================
#
# Basic string functions

my %CALENDAR_ARGS = (
  Gregorian => {
    class => 'DateTime',
    date_names => [qw(year month day)],
    duration_names => [qw(years months days hours minutes seconds)]
  },
  Hebrew => {
    class => 'DateTime::Calendar::Hebrew',
    date_names => [qw(year month day)]
  },
  Julian => {
    class => 'DateTime::Calendar::Julian',
    date_names => [qw(year month day)]
  },
  Jewish => {
    class => 'DateTime::Calendar::Hebrew',
    date_names => [qw(year month day)]
  },
  Hijri => {
    class => 'DateTime::Calendar::Hijri',
    date_names => [qw(year month day)]
  },
  Islamic => {
    class => 'DateTime::Calendar::Hijri',
    date_names => [qw(year month day)]
  },
  Mayan => {
    class => 'DateTime::Calendar::Mayan',
    date_names => [qw(baktun katun tun uinal kin)]
  },
  Pataphysical => {
    class => 'DateTime::Calendar::Pataphysical',
    date_names => [qw(year month day)]
  },
);

define
  'date' => (
  hold => 0,
  arity => 1,
  options => {
    # timezone => Dallycot::Value::String->new("UTC")
    calendar => Dallycot::Value::String->new("Gregorian")
  }
  ),
  sub {
  my ( $engine, $options, $vector ) = @_;

  # if( $year -> isa('Dallycot::Value::DateTime')) {
  #   # convert to gregorian
  #   return Dallycot::Value::DateTime -> new(
  #     object => $year,
  #     class => 'DateTime'
  #   );
  #   # return $year -> to_calendar('DateTime');
  # }

  if(!$vector -> isa('Dallycot::Value::Vector')) {
    croak 'The argument for date must be a vector of numerics';
  }
  if(!all { $_ -> isa('Dallycot::Value::Numeric') } $vector->values) {
    croak 'The argument for date must be a vector of numerics';
  }
  my @valid_calendars = grep { defined $CALENDAR_ARGS{$_}{date_names} } keys %CALENDAR_ARGS;

  if(!$options->{calendar}->isa('Dallycot::Value::String')) {
    croak 'The calendar option for date must be one of ' . join(', ', @valid_calendars);
  }

  my $calendar = $options->{calendar}->value;
  if(!any { $_ eq $calendar } @valid_calendars) {
    croak 'The calendar option for date must be one of ' . join(', ', @valid_calendars);
  }

  my @values = map { $_ -> value -> numify } $vector -> values;
  my @arg_names = @{$CALENDAR_ARGS{$calendar}{date_names}};
  my $class = $CALENDAR_ARGS{$calendar}{class};

  $#arg_names = $#values;
  my %args;

  @args{@arg_names} = @values;

  return Dallycot::Value::DateTime -> new(
    object => $class -> new(%args),
    class => $class
  );
};

define
  'calendar-convert' => (
    hold => 0,
    arity => [1,2],
    options => {}
  ), sub {
  my ( $engine, $options, $date, $calendar ) = @_;

  if($calendar && !$calendar->isa('Dallycot::Value::String')) {
    croak 'The calendar argument to calendar-convert must be a string';
  }

  if($calendar) {
    $calendar = $calendar->value;
  }
  else {
    $calendar = 'Gregorian';
  }

  if(!$CALENDAR_ARGS{$calendar}) {
    croak 'Calendar-convert only supports ' . join(', ', sort keys %CALENDAR_ARGS);
  }

  if(!$date -> isa('Dallycot::Value::DateTime')) {
    croak 'Calendar-convert expects a date object as its first argument';
  }

  return Dallycot::Value::DateTime->new(
    object => $date->value,
    class => $CALENDAR_ARGS{$calendar}{class}
  );
};

define
  'duration' => (
  hold => 0,
  arity => 1,
  options => {
    calendar => Dallycot::Value::String->new("Gregorian")
    }
  ),
  sub {
  my ( $engine, $options, $vector ) = @_;

  if(!$vector -> isa('Dallycot::Value::Vector')) {
    croak 'The argument for duration must be a vector of numerics';
  }
  if(!all { $_ -> isa('Dallycot::Value::Numeric') } $vector->values) {
    croak 'The argument for duration must be a vector of numerics';
  }

  my @valid_calendars = grep { defined $CALENDAR_ARGS{$_}{duration_names} } keys %CALENDAR_ARGS;

  if(!$options->{calendar}->isa('Dallycot::Value::String')) {
    croak 'The calendar option for duration must be one of ' . join(', ', @valid_calendars);
  }

  my $calendar = $options->{calendar}->value;
  if(!any { $_ eq $calendar } @valid_calendars) {
    croak 'The calendar option for duration must be one of ' . join(', ', @valid_calendars);
  }

  my @values = map { $_ -> value -> numify } $vector -> values;
  my @arg_names = @{$CALENDAR_ARGS{$calendar}{duration_names}};
  my $class = $CALENDAR_ARGS{$calendar}{class};

  $#arg_names = $#values;
  my %args;

  @args{@arg_names} = @values;

  return Dallycot::Value::Duration -> new(
    %args
  );
};

define now => (
  hold => 0,
  arity => 0,
  options => {
    timezone => Dallycot::Value::String->new("UTC")
  }
), sub {
  my( $engine, $options ) = @_;

  return Dallycot::Value::DateTime -> now(
    $options->{timezone}->value
  );
};

define 'convert-timezone' => (
  hold => 0,
  arity => [2],
  options => {}
), sub {
  my( $engine, $options, $datetime, $timezone ) = @_;

  if(!$datetime -> isa('Dallycot::Value::DateTime')) {
    croak 'in-timezone expects a date/time value as its first argument';
  }
  if(!$timezone -> isa('Dallycot::Value::String')) {
    croak 'in-timezone expects a string as its second argument';
  }

  return $datetime -> in_timezone($timezone -> value);
};

define 'parse-datetime' => (
  hold => 0,
  arity => 1,
  options => {
    language => undef, # <String>
    european => undef, # Boolean
    base => undef,     # DateTime
    'month-year' => undef, # Boolean
  }
), sub {
  my( $engine, $options, $string ) = @_;

  my %parse_options;

  if($options->{language}) {
    given(blessed $options->{language}) {
      when('Dallycot::Value::Vector') {
        $parse_options{lang} =
          grep { $_ }
          map { $_ -> value }
          grep { $_ -> isa('Dallycot::Value::String') }
          $options->{language}->values;
      }
      when('Dallycot::Value::String') {
        $parse_options{lang} = [ $options->{language}->value ];
      }
      default {
        croak "parse-datetime expects the language option to be a vector of String";
      }
    }
  }
  else {
    $parse_options{lang} = [ $string -> lang ];
  }
  if($options->{european}) {
    if($options->{european}->isa('Dallycot::Value::Boolean')) {
      $parse_options{european} = $options->{european}->value;
    }
    else {
      croak "parse-datetime expects the european option to be a Boolean";
    }
  }
  if($options->{base}) {
    if($options->{base}->isa('Dallycot::Value::DateTime')) {
      $parse_options{base} = DateTime->from_object(object => $options->{base}->[0]);
    }
    else {
      croak "parse-datetime expects the base option to be a date/time object";
    }
  }
  if($options->{'month-year'}) {
    if($options->{'month-year'}->isa('Dallycot::Value::Boolean')) {
      $parse_options{MMYY} = $options->{'month-year'}->value;
    }
    else {
      croak "parse-datetime expects the month-year option to be a Boolean";
    }
  }

  my $value = eval { DateTime::Format::Flexible->parse_datetime($string->value, %parse_options) };
  if($value) {
    return Dallycot::Value::DateTime->new(object => $value);
  }
  else {
    return Dallycot::Value::Undefined->new;
  }
};

# Hack to get the Islamic calendar convertable

package DateTime::Calendar::Hijri;

sub clone { $_[0] }

1;
