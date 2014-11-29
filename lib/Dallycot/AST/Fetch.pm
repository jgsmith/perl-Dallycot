package Dallycot::AST::Fetch;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub new {
  my($class, $identifier) = @_;

  $class = ref $class || $class;

  return bless [ $identifier ] => $class;
}

sub identifiers {
  my($self) = @_;

  if(@{$self} == 1) {
    return $self->[0];
  }
  else {
    return [ @{$self} ];
  }
}

sub to_string {
  my($self) = @_;

  return $self->[0];
}

sub execute {
  my($self, $engine, $d) = @_;

  my $registry = Dallycot::Registry -> instance;
  if(@$self > 1) {
    if($engine->has_namespace($self->[0])) {
      my $ns = $engine->get_namespace($self->[0]);
      if($registry->has_namespace($ns)) {
        if($registry->has_assignment($ns, $self->[1])) {
          $d -> resolve($registry->get_assignment($ns, $self->[1]));
        }
        else {
          $d -> reject(join(":", @$self) . " is undefined.");
        }
      }
      else {
        $d -> reject("The namespace \"$ns\" is unregistered.");
      }
    }
    else {
      $d -> reject("The namespace prefix \"@{[$self->[0]]}\" is undefined.");
    }
  }
  elsif($registry->has_assignment('', $self->[0])) {
    $d->resolve($registry->get_assignment('',$self->[0]));
  }
  elsif($engine->has_assignment($self->[0])) {
    $d->resolve($engine->get_assignment($self->[0]));
  }
  else {
    $d->reject($self->[0] . " is undefined.");
  }

  return;
}

1;
