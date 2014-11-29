package Dallycot::AST::Invert;

use strict;
use warnings;

use utf8;
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
          expression => Dallycot::AST::Invert->new($res->[0]),
          bindings => $res->[1],
          bindings_with_defaults => $res->[2],
          options => $res->[3],
          closure_environment => $res->[4],
          closure_namespaces => $res->[5]
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
