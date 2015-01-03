package Dallycot::AST::Sequence;

# ABSTRACT: Creates a new execution context for child nodes

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use List::Util qw(any);

sub to_string {
  my ($self) = @_;
  return join( "; ", map { $_->to_string } @{$self} );
}

sub simplify {
  my($self) = @_;

  return [ map { $_ -> simplify } @$self ] => __PACKAGE__;
}

sub check_for_common_mistakes {
  my($self) = @_;

  my @warnings;
  if(any { $_ -> isa('Dallycot::AST::Equality') } @{$self}[0..-2]) {
    push @warnings, 'Did you mean to assign instead of test for equality?';
  }
  if(any { !$_ -> isa('Dallycot::AST::Equality') && $_ -> isa('Dallycot::AST::ComparisonBase') } @{$self}[0..-2]) {
    push @warnings, 'Result of comparison is not used.';
  }
  push @warnings, map { $_ -> check_for_common_mistakes } @$self;
  return @warnings;
}

sub execute {
  my ( $self, $engine ) = @_;

  return $engine->with_child_scope()->execute(@$self);
}

1;
