package Dallycot::Value::Set;

# ABSTRACT: An in-memory set of unique values

use strict;
use warnings;

# RDF Bag

use utf8;
use parent 'Dallycot::Value::Collection';

use Promises qw(deferred collect);

sub as_text {
  my($self) = @_;

  "[" . join(", ", map { $_ -> as_text } @$self) . "]";
}

sub is_defined { return 1 }

sub is_empty {
  my($self) = @_;

  return @$self != 0;
}

sub calculate_length {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  $d->resolve( $engine->make_numeric( scalar @$self ) );

  return $d->promise;
}

sub head {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  if (@$self) {
    $d->resolve( $self->[0] );
  }
  else {
    $d->resolve( $engine->UNDEFINED );
  }

  return $d->promise;
}

sub tail {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  if (@$self) {
    $d->resolve( bless [ @$self[ 1 .. $#$self ] ] => __PACKAGE__ );
  }
  else {
    $d->resolve( Dallycot::Value::EmptyStream -> new() );
  }

  return $d->promise;
}

sub reduce {

}

sub apply_map {
  my ( $self, $engine, $d, $transform ) = @_;

  collect( map { $transform->apply( $engine, {}, $_ ) } @$self )->done(
  sub {
    my @values = map { @$_ } @_;
    $d->resolve( bless \@values => __PACKAGE__ );
  },
  sub {
    $d->reject(@_);
  }
  );

  return;
}

sub apply_filter {
  my ( $self, $engine, $d, $filter ) = @_;

  collect( map { $filter->apply( $engine, {}, $_ ) } @$self )->done(
  sub {
    my (@hits) = map { $_->value } map { @$_ } @_;
    my @values;
    for ( my $i = 0 ; $i < @hits ; $i++ ) {
      push @values, $self->[$i] if $hits[$i];
    }
    $d->resolve( bless \@values => __PACKAGE__ );
  },
  sub {
    $d->reject(@_);
  }
  );

  return;
}

1;
