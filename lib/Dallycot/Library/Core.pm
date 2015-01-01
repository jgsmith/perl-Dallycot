package Dallycot::Library::Core;

# ABSTRACT: Core library of useful functions

use strict;
use warnings;

use utf8;
BEGIN {
  require Dallycot::Library::Core::Functions;
  require Dallycot::Library::Core::Math;
  require Dallycot::Library::Core::Linguistics;
  require Dallycot::Library::Core::Streams;
  require Dallycot::Library::Core::Strings;
}

use Dallycot::Library;

use Dallycot::Context;
use Dallycot::Parser;
use Dallycot::Processor;

use Promises qw(deferred collect);

use experimental qw(switch);

ns 'http://www.dallycot.net/ns/misc/1.0#';

uses 'http://www.dallycot.net/ns/functions/1.0#',
     'http://www.dallycot.net/ns/linguistics/1.0#',
     'http://www.dallycot.net/ns/math/1.0#',
     'http://www.dallycot.net/ns/streams/1.0#',
     'http://www.dallycot.net/ns/strings/1.0#'
     ;

##
## Misc. functions
##

define length => (
  hold => 0,
  arity => 1,
  options => {},
), sub {
  my ( $engine, $options, $thing ) = @_;

  $thing->calculate_length($engine);
};

1;
