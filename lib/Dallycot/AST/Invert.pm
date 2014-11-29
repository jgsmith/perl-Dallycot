package Dallycot::AST::Invert;

use strict;
use warnings;

use parent 'Dallycot::AST';

sub new {
  my($class, $expr) = @_;

  $class = ref $class || $class;
  return bless [ $expr ] => $class;
}

sub execute {
  my($self, $engine, $d) = @_;

  $engine->execute($self->[0])->done(sub {
    my($res) = @_;

    if($res->isa('Dallycot::Value::Boolean')) {
      $d -> resolve($engine->make_boolean(!$res->value));
    }
    elsif($res->isa('Dallycot::Value::Lambda')) {
      $d -> resolve(
        Dallycot::Value::Lambda->new(
          Dallycot::AST::Invert->new($res->[0]),
          @$res[1,2,3,4,5]
        )
      );
    }
    else {
      $d -> resolve($engine->make_boolean(!$res->is_defined));
    }
  }, sub {
    $d -> reject(@_);
  });

  return;
}

1;
