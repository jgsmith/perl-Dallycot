use strict;
use warnings;
package Dallycot::Library;

# ABSTRACT: Base for adding namespaced functions to Dallycot.

use Moose;

use Dallycot::Processor;

has ns => ( is => 'rw' );
has functions ( isa => 'HashRef', is => 'ro', default => sub { +{ } } );

sub instance {
  my($self) = @_;

  my $class = ref $self || $self;
  ${"${class}::INSTANCE"} ||= $class -> new;
}

sub execute {
  my($self, $symbol, $context, $promise, @args) = @_;

  my $cb = $self->functions->{$symbol};

  if(!$cb) {
    $promise -> reject("$symbol is undefined");
  }
  elsif($cb->{arity} != @args) {
    $promise -> reject("Expected $cb->{arity} arguments but found @{[scalar(@args)]}");
  }
  else {
    my $engine = Dallycot::Processor -> new(
      context => $context -> new(
        parent => $context
      )
    );
    collect(
      map { $engine -> execute($_) } @args
    )->done(
      sub {
        my(@results) = map { @{$_} } @_;
        $cb -> ($engine, $promise, @results);
      },
      sub {
        $promise -> reject(@_);
      }
    );
  }
}

1;
