use strict;
use warnings;
package Dallycot::AST::ComparisonBase;

use parent 'Dallycot::AST';

use Promises qw(deferred);

sub execute {
  my($self, $engine, $d) = @_;

  my @expressions = @$self;

  $engine -> execute(shift @expressions) -> done(sub {
    $self -> _loop($engine, $d, $_[0], @expressions);
  }, sub {
    $d -> reject(@_);
  });
}

sub _loop {
  my($self, $engine, $d, $left_value, @expressions) = @_;

  if(!@expressions) {
    $d -> resolve($engine->TRUE);
  }
  else {
    $engine -> execute(shift @expressions)->done(sub {
      my($right_value) = @_;
      my $d2 = deferred;
      $engine->coerce($left_value, $right_value, [$left_value->type, $right_value->type])->done(sub {
        my($cleft, $cright) = @_;
        $self->_compare($engine, $d2, $cleft, $cright);
      }, sub {
        $d2 -> reject(@_);
      });
      $d2 -> promise -> done(sub {
        if($_[0]) {
          $self -> _loop($engine, $d, $right_value, @expressions);
        }
        else {
          $d -> resolve($engine->FALSE);
        }
      }, sub {
        $d -> reject(@_);
      });
    }, sub {
      $d -> reject(@_);
    });
  }
}

sub _compare {
  my($engine, $d2, $left_value, $right_value) = @_;

  $d2 -> reject("Comparison not defined");
}

1;
