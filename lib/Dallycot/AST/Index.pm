package Dallycot::AST::Index;

# ABSTRACT: Select value at given index in collection-like value

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Promises qw(deferred);

sub execute {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  my @expressions = @$self;

  if (@expressions) {
    $engine->execute( shift @expressions )->done(
      sub {
        my ($root) = @_;
        $self->_do_next_index(
          $engine, $d,
          root    => $root,
          indices => \@expressions
        );
      },
      sub {
        $d->reject(@_);
      }
    );
  }
  else {
    $d->reject('missing expressions');
  }

  return $d->promise;
}

sub _do_next_index {
  my ( $self, $engine, $d, %state ) = @_;
  my ( $root, $index_expr, @indices )
    = ( $state{root}, @{ $state{indices} || [] } );

  if ($index_expr) {
    $engine->execute($index_expr)->done(
      sub {
        my ($index) = @_;

        if ( $index->isa('Dallycot::Value::Numeric') ) {
          $index = $index->value;
        }
        else {
          $d->reject("Vector indices must be numeric");
          return;
        }
        $root->value_at( $engine, $index )->done(
          sub {
            $self->_do_next_index(
              $engine, $d,
              root    => $_[0],
              indices => \@indices
            );
          },
          sub {
            $d->reject(@_);
          }
        );
      },
      sub {
        $d->reject(@_);
      }
    );
  }
  else {
    $d->resolve($root);
  }

  return;
}

1;
