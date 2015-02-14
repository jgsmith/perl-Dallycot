package Dallycot::Library::Core;

# ABSTRACT: Core library of useful functions

use strict;
use warnings;

use utf8;

use Dallycot::Library;

ns 'http://www.dallycot.net/ns/core/1.0#';

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

define 'last' => <<'EOD';
Y(
  (self, stream) :> (
    (?(stream...)) : self(self, stream...)
    (            ) : stream'
  )
)
EOD

define nest => <<'EOD';
Y(
  (self, function, count) :> (
    (count > 3) : function . self(self, function, count-1)
    (count = 3) : function . function . function
    (count = 2) : function . function
    (count = 1) : function
    (         ) : { () }/1
  )
)
EOD

define map => <<'EOD';
Y(
  (self, mapper, stream) :> (
    (?stream) : [ mapper(stream'), self(self, mapper, stream...) ]
    (       ) : [ ]
  )
)
EOD

define filter => <<'EOD';
Y(
  (self, selector, stream) :> (
    (?stream) : (
      (selector(stream')) : [ stream', self(self, selector, stream...) ]
      (                 ) : self(self, selector, stream...)
    )
    (       ) : [ ]
  )
)
EOD

define 'list-cons' => <<'EOD';
Y(
  (self, first, second) :> (
    (?first) : [ first', self(self, first..., second)]
    (      ) : second
  )
)
EOD

define
  length => (
  hold    => 0,
  arity   => 1,
  options => {},
  ),
  sub {
  my ( $engine, $options, $thing ) = @_;

  $thing->calculate_length($engine);
  };

1;
