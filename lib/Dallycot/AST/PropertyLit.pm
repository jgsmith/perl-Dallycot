package Dallycot::AST::PropertyLit;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub execute {
  my ( $self, $engine, $d ) = @_;

  my ( $ns, $prop ) = @$self;

  if ( $engine->has_namespace($ns) ) {
    my $nshref = $engine->get_namespace($ns);
    $d->resolve( Dallycot::Value::URI->new( $nshref . $prop ) );
  }
  else {
    $d->reject("Undefined namespace '$ns'");
  }

  return;
}

1;
