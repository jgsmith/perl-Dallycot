package Dallycot::AST::PropWalk;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST::LoopBase';

use Promises qw(collect deferred);

sub to_string {

}

sub execute {
  my($self, $engine, $d) = @_;

  my($root_expr, @steps) = @$self;

  $engine->execute($root_expr)->done(sub {
    my($root) = [ @_ ];

    if(@steps) {
      $self -> process_loop($engine, $d, root => $root, steps => \@steps);
    }
    elsif(@$root > 1) {
      $d -> resolve(bless $root => "Dallycot::Value::Set");
    }
    else {
      $d -> resolve(@$root);
    }
  }, sub {
    $d -> reject(@_);
  });

  return;
}

sub process_loop {
  my($self, $engine, $d, %state) = @_;

  my($root, $step, @steps) = ($state{root}, @{$state{steps}||[]});

  collect(
    map {
      $step -> step($engine, $_)
    } @$root
  )->done(sub {
    my(@results) = map { @$_ } @_;
    if(@steps) {
      $self -> _loop($engine, $d, root => \@results, steps => \@steps);
    }
    elsif(@results > 1) {
      $d -> resolve(bless \@results => "Dallycot::Value::Set");
    }
    elsif(@results == 1) {
      $d -> resolve(@results);
    }
    else {
      $d -> resolve($engine->UNDEFINED);
    }
  }, sub {
    $d -> reject(@_);
  });

  return;
}


1;
