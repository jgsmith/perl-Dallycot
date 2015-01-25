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

sub is_declarative { return 1 }

sub identifier {
  my($self) = @_;

  return $self -> [0];
}

sub simplify {
  my($self) = @_;

  return bless [ $self -> [0], $self -> [1] -> simplify ] => __PACKAGE__;
}

sub execute {
  my ( $self, $engine ) = @_;

  my $registry = Dallycot::Registry->instance;

  my $d;

  if ( $registry->has_assignment( '', $self->[0] ) ) {
    $d = $registry->get_assignment( '', $self->[0] );
    if($d -> is_resolved) {
      $d = deferred;
      $d->reject('Core definitions may not be redefined.');
      return $d -> promise;
    }
  }
  elsif( $engine -> has_assignment( $self->[0] ) ) {
    $d = $engine -> get_assignment( $self -> [0] );
    if($d -> is_resolved) {
      $d = deferred;
      $d -> reject('Unable to redefine '.$self->[0]);
      return $d -> promise;
    }
  }
  else {
    $d = $engine->add_assignment( $self->[0] );
  }

  $engine->execute( $self->[1] )->done(
    sub {
      my ($result) = @_;
      $d->resolve(@_);
    },
    sub {
      $d->reject(@_);
    }
  );

  return $d->promise;
}

1;
