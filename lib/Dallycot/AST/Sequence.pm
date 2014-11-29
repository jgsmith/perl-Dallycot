package Dallycot::AST::Sequence;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub to_string {
  my ($self) = @_;
  return join( "; ", map { $_->to_string } @{$self} );
}

sub execute {
  my ( $self, $engine, $d ) = @_;

  my $new_engine = $engine->with_child_scope();

  $new_engine->execute(@$self)->done(
    sub {
      $d->resolve(@_);
    },
    sub {
      $d->reject(@_);
    }
  );

  return;
}

1;
