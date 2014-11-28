use strict;
use warnings;
package Dallycot::Value::ClosedRange;

# No RDF equivalent - finite list of items

use parent 'Dallycot::Value::Collection';

use Promises qw(deferred);

use constant {
  FIRST => 0,
  LAST => 1,
  DIRECTION => 2
};

sub reverse {
  my($self) = @_;

  my $d = deferred;

  $d -> resolve(bless [ $self->[0], $self->[1], -$self->[2] ] => __PACKAGE__);

  $d -> promise;
}

sub type { 'Range' }

sub head {
  my($self) = @_;

  my $d = deferred;

  $d -> resolve($self->[0]);

  $d -> promise;
}

sub tail {
  my($self, $engine) = @_;

  my $d = deferred;

  my $equal_p = deferred;

  $self->[0]->is_equal($engine, $equal_p, $self->[1]);
  $equal_p -> promise -> done(sub {
    my($f) = @_;

    if($f) {
      $d -> resolve(bless [] => 'Dallycot::Value::EmptyStream');
    }
    else {
      my $next_p = deferred;
      if($self->[DIRECTION] > 0) {
        $next_p = $self->[0]->successor;
      }
      else {
        $next_p = $self->[0]->predecessor;
      }
      $next_p -> done(sub {
        my($next) = @_;
        $d -> resolve(bless [
            $next,
            $self->[LAST],
            $self->[DIRECTION]
          ] => __PACKAGE__
        );
      }, sub {
        $d -> reject(@_);
      });
    }
  }, sub {
    $d -> reject(@_);
  });

  $d -> promise;
}

# We pass each value in the range through the reduction
sub reduce {
  my($self, $engine, $start, $lambda) = @_;

  if($self->[DIRECTION] < 0) {
    return $self -> reverse -> then(sub {
      $_[0]->reduce($engine, $start, $lambda);
    });
  }

  my $d = deferred;

  $self->_reduce_loop($engine, $d, $start, $lambda, $self->[0]);

  $d -> promise;
}

sub _reduce_loop {
  my($self, $engine, $promise, $start, $lambda, $value) = @_;

  my $d = deferred;
  $value->is_less_or_equal($engine, $d, $self->[1]);
  $d -> done(sub {
    my($flag) = @_;

    if($flag) {
      $lambda -> apply($engine, {}, $start, $value) -> done(sub {
        my($next_start) = @_;
        $value -> successor -> done(sub {
          my($next_value) = @_;
          $self->_reduce_loop($engine, $promise, $next_start, $lambda, $next_value);
        }, sub {
          $promise->reject(@_);
        });
      }, sub {
        $promise->reject(@_);
      });
    }
    else {
      $promise->resolve($start);
    }
  }, sub {
    $promise -> reject(@_);
  });
}

1;
