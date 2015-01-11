package Dallycot::Value::OpenRange;

# ABSTRACT: An open range (semi-infinite) of integers

use strict;
use warnings;

# No RDF equivalent - continuous list generation of items

use utf8;
use parent 'Dallycot::Value::Collection';

use Promises qw(deferred);

sub _type { return 'Range'  }

sub as_text {
  my($self) = @_;

  $self -> [0] -> as_text . "..";
}

sub is_empty { return }

sub calculate_length {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  $d->resolve( Dallycot::Value::Numeric -> new( Math::BigRat->binf() ) );

  return $d->promise;
}

sub head {
  my ($self) = @_;

  my $d = deferred;

  $d->resolve( $self->[0] );

  return $d->promise;
}

sub tail {
  my ($self) = @_;

  my $d = deferred;

  $self->[0]->successor->done(
    sub {
      my ($next) = @_;

      $d->resolve( bless [$next] => __PACKAGE__ );
    },
    sub {
      $d->reject(@_);
    }
  );

  return $d->promise;
}

sub apply_map {
  my ( $self, $engine, $d, $transform ) = @_;

  my $map_t = $engine->make_map($transform);

  $map_t->apply( $engine, {}, $self )->done(
    sub {
      $d->resolve(@_);
    },
    sub {
      $d->reject(@_);
    }
  );

  return;
}

sub apply_filter {
  my ( $self, $engine, $d, $filter ) = @_;

  my $filter_t = $engine->make_filter($filter);

  $filter_t->apply( $engine, {}, $self )->done(
    sub {
      $d->resolve(@_);
    },
    sub {
      $d->reject(@_);
    }
  );

  return;
}

sub reduce {
  my ( $self, $engine, $start, $lambda ) = @_;

  # since we're open ended, we know we can't reduce
  # might want a 'reduce until...', though we can do this
  # with filters on a sequence
  my $promise = deferred;

  $promise->reject("An open-ended Range can not be reduced.");

  return $promise->promise;
}

1;
