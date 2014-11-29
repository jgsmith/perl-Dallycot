package Dallycot::AST::ComparisonBase;

use strict;
use warnings;

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

  return;
}

sub _loop {
  my($self, $engine, $d, $left_value, @expressions) = @_;

  if(!@expressions) {
    $d -> resolve($engine-> TRUE);
  }
  else {
    $engine -> execute(shift @expressions)->done(sub {
      my($right_value) = @_;
      $engine->coerce($left_value, $right_value, [$left_value->type, $right_value->type])->done(sub {
        my($cleft, $cright) = @_;
        $self->_compare($engine, $cleft, $cright) -> done(sub {
          if($_[0]) {
            $self -> _loop($engine, $d, $right_value, @expressions);
          }
          else {
            $d -> resolve($engine-> FALSE);
          }
        }, sub {
          $d -> reject(@_);
        });
      }, sub {
        $d -> reject(@_);
      });
    }, sub {
      $d -> reject(@_);
    });
  }

  return;
}

sub _compare {
  my($engine, $left_value, $right_value) = @_;

  my $d = deferred;

  $d -> reject("Comparison not defined");

  return $d -> promise;
}

1;
