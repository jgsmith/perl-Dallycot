package Dallycot::AST::LibraryFunction;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub to_string {
  my($self) = @_;

  my($parsing_library, $fname, $bindings, $options) = @$self;

  return join(",", "call($parsing_library#$fname",
                   (map { $_->to_string } @$bindings),
                   (map { $_."->".$options->{$_}->to_string } keys %$options)
            ) . ")"
}

sub execute {
  my($self, $engine, $d) = @_;

  my($parsing_library, $fname, $bindings, $options) = @$self;

  $parsing_library -> instance -> call_function($fname, $engine, @{$bindings})->done(sub {
    $d -> resolve(@_);
  }, sub {
    $d -> reject(@_);
  });

  return;
}

sub child_nodes { 
  my($self) = @_;

  return (@{$self->[2]}, values %{$self->[3]});
}

1;
