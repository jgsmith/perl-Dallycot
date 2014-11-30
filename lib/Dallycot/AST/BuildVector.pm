package Dallycot::AST::BuildVector;

# ABSTRACT: Create vector value

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Promises qw(deferred);

sub execute {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  $engine->collect(@$self)->done(
    sub {
      my (@bits) = @_;

      $d->resolve( bless \@bits => 'Dallycot::Value::Vector' );
    },
    sub {
      $d->reject(@_);
    }
  );

  return $d->promise;
}

1;
