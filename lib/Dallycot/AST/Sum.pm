package Dallycot::AST::Sum;

# ABSTRACT: Calculates the sum of a list of values

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Readonly;

Readonly my $NUMERIC => ['Numeric'];

sub to_string {
  my ($self) = @_;

  return "(" . join( "+", map { $_->to_string } @{$self} ) . ")";
}

sub to_rdf {
  my($self, $model) = @_;

  #
  # node -> expression_set -> [ ... ]
  #
  return $model -> apply(
    $model -> meta_uri('loc:sum'),
    [ @$self ],
    {}
  );
  # my $bnode = $model->bnode;
  # $model -> add_type($bnode, 'loc:Sum');
  #
  # foreach my $expr (@$self) {
  #   $model -> add_expression($bnode, $expr);
  # }
  # return $bnode;
}

sub execute {
  my ( $self, $engine ) = @_;

  return $engine->collect( map { [ $_, $NUMERIC ] } @$self )->then(
    sub {
      my (@values) = map { $_->value } @_;

      my $acc = ( pop @values )->copy;

      while (@values) {
        $acc += ( pop @values );
      }

      return Dallycot::Value::Numeric->new($acc);
    }
  );
}

1;
