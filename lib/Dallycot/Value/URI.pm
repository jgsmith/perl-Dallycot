package Dallycot::Value::URI;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::Value::Any';

use Promises qw(deferred);

use experimental qw(switch);

sub new {
  my($class, $uri) = @_;

  $class = ref $class || $class;

  return bless [ $uri ] => $class;
}

sub calculate_length {
  my($self, $engine) = @_;

  my $d = deferred;

  $d -> resolve($engine->make_numeric(length $self->[0]));

  return $d -> promise;
}

sub value_at {
  my($self, $engine, $index) = @_;

  my $d = deferred;

  $d -> resolve(bless [ substr($self->[0], $index-1, 1), 'en' ] => 'Dallycot::Value::String');

  return $d -> promise;
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

  return;
}

1;
