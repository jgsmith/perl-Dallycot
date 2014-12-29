package Dallycot::Library::Core::Functions;

# ABSTRACT: Core library of useful functions for functions

use strict;
use warnings;

use utf8;
use Dallycot::Library;

use Dallycot::Context;
use Dallycot::Parser;
use Dallycot::Processor;

use Promises qw(deferred collect);

use experimental qw(switch);

ns 'https://www.dallycot.io/ns/functions/1.0#';

define Y => '(function) :> function(function, ___)';

define foldl => <<'EOD';
(
  folder := Y(
    (self, pad, function, stream) :> (
      (?stream) : (
        next := function(pad, stream');
        [ next, self(self, next, function, stream...) ]
      )
      ( ) : [ ]
    )
  );
  (initial, function, stream) :> (
    (?stream) : folder(initial, function, stream)
    (       ) : [ initial ]
  )
)
EOD

define foldl1 => <<'EOD';
  (function, stream) :> (
    (?stream) : foldl(stream', function, stream...)
    (       ) : [ ]
  )
EOD

1;
