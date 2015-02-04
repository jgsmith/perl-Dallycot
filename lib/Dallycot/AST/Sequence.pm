package Dallycot::AST::Sequence;

# ABSTRACT: Creates a new execution context for child nodes

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use List::Util   qw(any);
use Promises     qw(deferred);
use Scalar::Util qw(blessed);


sub new {
  my($class, @expressions) = @_;

  my @declarations = grep { blessed($_) && $_ -> is_declarative } @expressions;
  my @statements = grep { blessed($_) && !$_ -> is_declarative } @expressions;

  my @assignment_names = grep { defined } map { $_ -> identifier } @declarations;

  my %namespace_prefixes = map {
    $_->prefix => $_->namespace
  } grep {
    $_ -> isa('Dallycot::AST::XmlnsDef')
  } @declarations;

  @declarations = grep { !$_ -> isa('Dallycot::AST::XmlnsDef') } @declarations;

  my @namespace_searches = map {
    $_->namespace
  } grep {
    $_ -> isa('Dallycot::AST::Uses')
  } @declarations;

  @declarations = grep { !$_ -> isa('Dallycot::AST::Uses') } @declarations;

  $class = ref $class || $class;

  return bless [ \@declarations, \@statements, \@assignment_names, \%namespace_prefixes, \@namespace_searches ] => $class;
}

sub to_string {
  my ($self) = @_;
  return join( "; ",
    (map { 'uses "' . $_ . '"' } @{$self->[4]}),
    (map { "ns:$_ := \"" . $self->[3]->{$_} . "\"" } keys %{$self->[3]}),
    map { $_->to_string } @{$self->[0]}, @{$self -> [1]}
  );
}

sub simplify {
  my($self) = @_;

  return $self -> new(
    map { $_ -> simplify } @{$self -> [0]}, @{$self -> [1]}
  );
}

sub check_for_common_mistakes {
  my($self) = @_;

  my @warnings;
  # if(any { $_ -> isa('Dallycot::AST::Equality') } @{$self}[1][0..-2]) {
  #   push @warnings, 'Did you mean to assign instead of test for equality?';
  # }
  # if(any { !$_ -> isa('Dallycot::AST::Equality') && $_ -> isa('Dallycot::AST::ComparisonBase') } @{$self}[1][0..-2]) {
  #   push @warnings, 'Result of comparison is not used.';
  # }
  # push @warnings, map { $_ -> check_for_common_mistakes } @$self;
  return @warnings;
}

sub execute {
  my ( $self, $engine ) = @_;

  my $child_scope = $engine->with_child_scope();

  foreach my $ident (@{$self -> [2]}) {
    $child_scope -> add_assignment( $ident );
  }

  $child_scope -> append_namespace_search_path(@{$self -> [4]});

  for my $ns (keys %{$self->[3]}) {
    $engine -> add_namespace($ns, $self->[3]->{$ns});
  }

  $child_scope->collect(@{$self->[0]})->done(sub{});

  return $child_scope->execute(@{$self->[1]});
}

sub identifiers {
  my($self) = @_;

  my @identifiers = map { $_ -> identifiers } $self->child_nodes;
  my %assignments = map { $_ => 1 } @{$self->[2]};
  grep { !$assignments{$_} } @identifiers;
}

sub child_nodes {
  my ($self) = @_;

  return (@{$self->[0]}, @{$self->[1]});
}

1;
