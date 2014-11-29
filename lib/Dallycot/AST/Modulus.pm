package Dallycot::AST::Modulus;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub to_string {
  my $self = shift;
  return join(" mod ", map { $_ -> to_string } @$self);
}

sub execute {
  my($self, $engine, $d) = @_;

  my @expressions = @$self;
  $engine->execute((shift @expressions), ['Numeric'])->done(sub {
    my($left_value) = @_;

    $self -> process_loop($engine, $d, base => $left_value, expressions => \@expressions);
  }, sub {
    $d -> reject(@_);
  });

  return;
}

sub process_loop {
  my($self, $engine, $d, %state) = @_;
  my($left_value, $right_expr, @expressions) = ($state{base}, @{$state{expressions}||[]});

  if(!@expressions) {
    $engine->execute($right_expr, ['Numeric'])->done(sub {
      my($right_value) = @_;
      $d -> resolve(
        $engine->make_numeric(
          $left_value->value->copy->bmod($right_value->value)
        )
      );
    }, sub {
      $d -> reject(@_);
    });
  }
  else {
    $engine->execute($right_expr, ['Numeric']) -> done(sub {
      my($right_value) = @_;
      $left_value = $left_value->copy->bmod($right_value->value);
      if($left_value->is_zero) {
        $d->resolve($engine->make_numeric($left_value));
      }
      else {
        $self -> process_loop($engine, $d, base => $left_value, expressions => \@expressions);
      }
    }, sub {
      $d->reject(@_);
    });
  }

  return;
}

1;
