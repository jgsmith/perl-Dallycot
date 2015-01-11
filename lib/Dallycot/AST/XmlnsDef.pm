package Dallycot::AST::XmlnsDef;

# ABSTRACT: A no-op placeholder

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use Promises qw(deferred);

sub to_json {
}

sub to_string { return "" }

sub as_text {
  my($self) = @_;

  my($prefix, $uri) = @$self;

  "ns:$prefix := <" . $uri->value . ">";
}

sub execute {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  $engine -> add_namespace($self->[0], $self->[1]->value);

  $d->resolve( $self->[1] );

  return $d->promise;
}

1;