package Dallycot::Value::Stream;

# ABSTRACT: A linked list of values with a possible generator

use strict;
use warnings;

# RDF List
use utf8;
use Readonly;

Readonly my $HEAD         => 0;
Readonly my $TAIL         => 1;
Readonly my $TAIL_PROMISE => 2;

use parent 'Dallycot::Value::Collection';

use experimental qw(switch);

use Promises qw(deferred);

sub new {
  my ( $class, $head, $tail, $promise ) = @_;
  $class = ref $class || $class;
  return bless [ $head, $tail, $promise ] => $class;
}

sub calculate_length {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  my $ptr = $self;

  my $count = 1;

  while ( $ptr->[$TAIL] ) {
    $ptr = $ptr->[$TAIL];
  }

  if ( $ptr->[$TAIL_PROMISE] ) {
    $d->resolve( $engine->make_numeric( Math::BigRat->binf() ) );
  }
  else {
    $d->resolve( $engine->make_numeric($count) );
  }

  return $d->promise;
}

sub _resolve_tail_promise {
  my ( $self, $engine ) = @_;

  return $self->[$TAIL_PROMISE]->apply( $engine, {} )->then(
    sub {
      my ($list_tail) = @_;
      given ( ref $list_tail ) {
        when (__PACKAGE__) {
          $self->[$TAIL]         = $list_tail;
          $self->[$TAIL_PROMISE] = undef;
        }
        when ('Dallycot::Value::Vector') {

          # convert finite vector into linked list
          my @values = @$list_tail;
          my $point  = $self;
          while (@values) {
            $point->[$TAIL] = $self->new( shift @values );
            $point = $point->[$TAIL];
          }
        }
        default {
          $self->[$TAIL]         = $list_tail;
          $self->[$TAIL_PROMISE] = undef;
        }
      }
    }
  );
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

sub drop {
  my ( $self, $engine ) = @_;

  return;
}

sub value_at {
  my ( $self, $engine, $index ) = @_;

  if ( $index == 1 ) {
    return $self->head($engine);
  }

  my $d = deferred;

  if ( $index < 1 ) {
    $d->resolve( $engine->UNDEFINED );
  }
  else {
    # we want to keep resolving tails until we get somewhere
    $self->_walk_tail( $engine, $index - 1 )->done(
      sub {
        $_[0]->head->done(
          sub {
            $d->resolve(@_);
          },
          sub {
            $d->reject(@_);
          }
        );
      },
      sub {
        $d->reject(@_);
      }
    );
  }

  return $d->promise;
}

sub _walk_tail {
  my ( $self, $engine, $count ) = @_;

  my $d = deferred;

  if ( $count > 0 ) {
    $self->tail($engine)->done(
      sub {
        my ($tail) = @_;
        $tail->_walk_tail( $engine, $count - 1 )->done(
          sub {
            $d->resolve(@_);
          },
          sub {
            $d->reject(@_);
          }
        );
      },
      sub {
        $d->reject(@_);
      }
    );
  }
  else {
    $d->resolve($self);
  }

  return $d->promise;
}

sub head {
  my ( $self, $engine ) = @_;

  my $p = deferred;

  if ( defined $self->[$HEAD] ) {
    $p->resolve( $self->[0] );
  }
  else {
    $p->resolve( bless [] => 'Dallycot::Value::Undefined' );
  }

  return $p->promise;
}

sub tail {
  my ( $self, $engine ) = @_;

  my $p = deferred;

  if ( defined $self->[$TAIL] ) {
    $p->resolve( $self->[$TAIL] );
  }
  elsif ( defined $self->[$TAIL_PROMISE] ) {
    $self->_resolve_tail_promise($engine)->done(
      sub {
        if ( defined $self->[$TAIL] ) {
          $p->resolve( $self->[$TAIL] );
        }
        else {
          $p->reject('The tail operator expects a stream-like object.');
        }
      },
      sub {
        $p->reject(@_);
      }
    );
  }
  else {
    $p->resolve( bless [] => 'Dallycot::Value::EmptyStream' );
  }

  return $p->promise;
}

sub reduce {
  my ( $self, $engine, $start, $lambda ) = @_;

  my $promise = deferred;

  $self->_reduce_loop(
    $engine, $promise,
    start  => $start,
    lambda => $lambda,
    stream => $self
  );

  return $promise->promise;
}

sub _reduce_loop {
  my ( $self, $engine, $promise, %params ) = @_;

  my ( $start, $lambda, $stream ) = @params{qw(start lambda stream)};

  if ( $stream->is_defined ) {
    $stream->head->done(
      sub {
        my ($head) = @_;

        $stream->tail->done(
          sub {
            my ($tail) = @_;

            $lambda->apply( $engine, {}, $start, $head )->done(
              sub {
                my ($next_start) = @_;
                $self->_reduce_loop(
                  $engine, $promise,
                  start  => $next_start,
                  lambda => $lambda,
                  stream => $tail
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
      },
      sub {
        $promise->reject(@_);
      }
    );
  }
  else {
    $promise->resolve($start);
  }

  return;
}

1;
