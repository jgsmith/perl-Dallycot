package Dallycot::AST::Assign;

# ABSTRACT: Store result of expression in environment

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Promises qw(deferred);

sub to_string {
  my ($self) = @_;

  return $self->[0] . " := " . $self->[1]->to_string;
}

sub simplify {
  my($self) = @_;

  return bless [ $self -> [0], $self -> [1] -> simplify ] => __PACKAGE__;
}

sub execute {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  my $registry = Dallycot::Registry->instance;

  if ( $registry->has_assignment( '', $self->[0] ) ) {
    $d->reject('Core definitions may not be redefined.');
  }
  $engine->execute( $self->[1] )->done(
    sub {
      my ($result) = @_;
      my $worked = eval {
        $engine->add_assignment( $self->[0], $result );
        1;
      };
      if ($@) {
        $d->reject($@);
      }
      elsif ( !$worked ) {
        $d->reject( "Unable to assign to " . $self->[0] );
      }
      else {
        $d->resolve($result);
      }
    },
    sub {
      $d->reject(@_);
    }
  );

  return $d->promise;
}

1;
