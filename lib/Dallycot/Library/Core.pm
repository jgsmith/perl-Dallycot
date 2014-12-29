package Dallycot::Library::Core;

# ABSTRACT: Core library of useful functions

use strict;
use warnings;

use utf8;
use Dallycot::Library::Core::Functions;
use Dallycot::Library::Core::Math;
use Dallycot::Library::Core::Linguistics;
use Dallycot::Library::Core::Streams;
use Dallycot::Library::Core::Strings;

use Dallycot::Library;

use Dallycot::Context;
use Dallycot::Parser;
use Dallycot::Processor;

use Promises qw(deferred collect);

use experimental qw(switch);

ns 'https://www.dallycot.io/ns/misc/1.0#';

uses 'https://www.dallycot.io/ns/functions/1.0#',
     'https://www.dallycot.io/ns/linguistics/1.0#',
     'https://www.dallycot.io/ns/math/1.0#',
     'https://www.dallycot.io/ns/streams/1.0#',
     'https://www.dallycot.io/ns/strings/1.0#'
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
