use strict;
use warnings;
package Dallycot::Value::URI;

use parent 'Dallycot::Value::Any';

use Promises qw(deferred);

use experimental qw(switch);

sub new {
  my($class, $uri) = @_;

  $class = ref $class || $class;

  bless [ $uri ] => $class;
}

sub length {
  my($self, $engine, $d) = @_;

  $d -> resolve($engine->Numeric(CORE::length $self->[0]));
}

sub value_at {
  my($self, $engine, $index) = @_;

  my $d = deferred;

  $d -> resolve(bless [ substr($self->[0], $index-1, 1), 'en' ] => 'Dallycot::Value::String');

  $d -> promise;
}

sub execute {
  my($self, $engine, $d) = @_;

  my $url = $self->[0];

  my $resolver = Dallycot::Resolver -> instance;
  $resolver->get($url)->done(sub {
    $d -> resolve(@_);
  }, sub {
    $d -> reject(@_);
  });
}

1;
