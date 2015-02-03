package Dallycot::Value::ClosedRange;

# ABSTRACT: A finite range of integers

use strict;
use warnings;

# No RDF equivalent - finite list of items

use utf8;
use parent 'Dallycot::Value::Collection';

use Promises qw(deferred);

use Readonly;

Readonly my $FIRST     => 0;
Readonly my $LAST      => 1;
Readonly my $DIRECTION => 2;

sub as_text {
  my($self) = @_;

  return $self->[$FIRST]->as_text . ".." . $self->[$LAST] -> as_text;
}

sub calculate_length {
  my ( $self, $engine ) = @_;

  my $diff = $self->[$LAST]->value - $self->[$FIRST]->value;

  return Dallycot::Value::Numeric -> new( $diff -> babs + 1  );
}

sub is_defined { return 1 }

sub is_empty { return }

sub calculate_reverse {
  my ($self) = @_;

  my $d = deferred;

  $d->resolve(
    bless [ $self->[$LAST], $self->[$FIRST], -$self->[$DIRECTION] ] =>
      __PACKAGE__ );

  return $d->promise;
}

sub _type { return 'Range' }

sub head {
  my ($self) = @_;

  my $d = deferred;

  $d->resolve( $self->[$FIRST] );

  return $d->promise;
}

sub tail {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  $self->[$FIRST]->is_equal( $engine, $self->[$LAST] )->done(
    sub {
      my ($f) = @_;

      if ($f) {
        $d->resolve( Dallycot::Value::EmptyStream->new() );
      }
      else {
        my $next_p = deferred;
        if ( $self->[$DIRECTION] > 0 ) {
          $next_p = $self->[$FIRST]->successor;
        }
        else {
          $next_p = $self->[$FIRST]->predecessor;
        }
        $next_p->done(
          sub {
            my ($next) = @_;
            $d->resolve(
              bless [ $next, $self->[$LAST], $self->[$DIRECTION] ] =>
                __PACKAGE__ );
          },
          sub {
            $d->reject(@_);
          }
        );
      }
    },
    sub {
      $d->reject(@_);
    }
  );

  return $d->promise;
}

# We pass each value in the range through the reduction
sub reduce {
  my ( $self, $engine, $start, $lambda ) = @_;

  if ( $self->[$DIRECTION] < 0 ) {
    return $self->reverse->then(
      sub {
        $_[0]->reduce( $engine, $start, $lambda );
      }
    );
  }

  my $d = deferred;

  $self->_reduce_loop(
    $engine, $d,
    start  => $start,
    lambda => $lambda,
    value  => $self->[$FIRST]
  );

  return $d->promise;
}

sub _reduce_loop {
  my ( $self, $engine, $promise, %options ) = @_;

  my ( $start, $lambda, $value ) = @options{qw(start lambda value)};

  $value->is_less_or_equal( $engine, $self->[$LAST] )->done(
    sub {
      my ($flag) = @_;

      if ($flag) {
        $lambda->apply( $engine, {}, $start, $value )->done(
          sub {
            my ($next_start) = @_;
            $value->successor->done(
              sub {
                my ($next_value) = @_;
                $self->_reduce_loop(
                  $engine, $promise,
                  start  => $next_start,
                  lambda => $lambda,
                  value  => $next_value
                );
              },
              sub {
                $promise->reject(@_);
              }
            );
          },
          sub {
            $promise->reject(@_);
          }
        );
      }
      else {
        $promise->resolve($start);
      }
    },
    sub {
      $promise->reject(@_);
    }
  );

  return;
}

sub apply_map {
  my ( $self, $engine, $transform ) = @_;

  $engine->make_map($transform) -> then(sub {
    my($map_t) = @_;

    return $map_t -> apply( $engine, {}, $self );
  });
}

sub apply_filter {
  my( $self, $engine, $filter ) = @_;

  $engine->make_filter($filter) -> then(sub {
    my($filter_t) = @_;

    return $filter_t -> apply( $engine, {}, $self);
  });
}


1;
