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

  my $d = deferred;

  $engine->collect(@$self)->done(
    sub {
      my (@values) = map { @$_ } @_;

      my @types = map { $_->type } @values;
      $engine->coerce( @values, \@types )->done(
        sub {
          my (@new_values) = @_;

          # now make sure values are all different
          my %seen;
          my @unique = grep { !$seen{ $_->id }++ } @new_values;
          if ( @unique != @new_values ) {
            $d->resolve( $engine->FALSE );
          }
          else {
            $d->resolve( $engine->TRUE );
          }
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

  return $d->promise;
}

1;
