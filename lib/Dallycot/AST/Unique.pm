package Dallycot::AST::Unique;

# ABSTRACT: Test that all values are unique

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Promises qw(deferred);

sub to_string {
  my ($self) = @_;
  return join( " <> ", map { $_->to_string } @{$self} );
}

sub execute {
  my ( $self, $engine ) = @_;

  return $engine->collect(@$self)->then(
    sub {
      my (@values) = map { @$_ } @_;

      my @types = map { $_->type } @values;
      return $engine->coerce( @values, \@types )->then(
        sub {
          my (@new_values) = @_;

          # now make sure values are all different
          my %seen;
          my @unique = grep { !$seen{ $_->id }++ } @new_values;
          if ( @unique != @new_values ) {
            return $engine->FALSE;
          }
          else {
            return $engine->TRUE;
          }
        }
      );
    }
  );
}

1;
