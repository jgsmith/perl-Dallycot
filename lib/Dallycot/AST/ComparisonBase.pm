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
  my($self, $engine, $d, $left, @expressions) = @_;

  if(!@expressions) {
    $d -> resolve($engine->TRUE);
  }
  else {
    $engine -> execute(shift @expressions)->done(sub {
      my($right) = @_;
      my $d2 = deferred;
      $engine->coerce($left, $right, [$left->type, $right->type])->done(sub {
        my($cleft, $cright) = @_;
        $self->_compare($engine, $d2, $cleft, $cright);
      }, sub {
        $d2 -> reject(@_);
      });
      $d2 -> promise -> done(sub {
        if($_[0]) {
          $self -> _loop($engine, $d, $right, @expressions);
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
  my($engine, $d2, $left, $right) = @_;

  $d2 -> reject("Comparison not defined");
}

1;
