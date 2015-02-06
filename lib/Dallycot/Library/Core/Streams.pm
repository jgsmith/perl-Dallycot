package Dallycot::Library::Core::Streams;

# ABSTRACT: Core library of useful streams and stream functions

use strict;
use warnings;

use utf8;
use Dallycot::Library;

use Dallycot::Library::Core       ();
use Dallycot::Library::Core::Math ();

use Promises qw(deferred collect);

use experimental qw(switch);

ns 'http://www.dallycot.net/ns/streams/1.0#';

uses 'http://www.dallycot.net/ns/core/1.0#';

define 'set-first' => '(s, sh) :> [sh, s... ]';

define 'set-rest' => "(s, st) :> [ s', st ]";

define 'insert-after' => "(s, m) :> [ s', m, s... ]";

define upfrom => q{ Y( (self, n) :> [ n, self(self, n + 1) ] ) };

define downfrom => <<'EOD';
Y(
  (self, n) :> (
    (n > 0) : [ n, ff(ff, n - 1) ]
    (n = 0) : [ 0 ]
    (     ) : [   ]
  )
)
EOD

define range => <<'EOD';
Y(
  (self, m, n) :> (
    (m > n) : [ m, self(self, m - 1, n) ]
    (m = n) : [ m ]
    (m < n) : [ m, self(self, m + 1, n) ]
    (     ) : [ ]
  )
)
EOD

1;
