package Dallycot::Library::CLI;

# ABSTRACT: functions for use with the command line interface

use strict;
use warnings;

use utf8;
use Dallycot::Library;

use Promises qw(deferred collect);

use experimental qw(switch);

ns 'http://www.dallycot.net/ns/cli/1.0#';

define print => (
  hold => 0,
  arity => [0],
  options => {}
), sub {
  my($engine, $options, @things) = @_;

  my $d = deferred;

  for my $thing (@things) {
    if($thing -> isa('Dallycot::Value::String')) {
      $engine -> channel_send('$OUTPUT', $thing -> value);
    }
    else {
      $engine -> channel_send('$OUTPUT', $thing -> as_text);
    }
  }
  $engine -> channel_send('$OUTPUT', "\n");
  $d -> resolve($engine->TRUE);
  return $d->promise;
};

1;
