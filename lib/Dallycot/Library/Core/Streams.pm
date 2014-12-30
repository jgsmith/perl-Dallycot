package Dallycot::Library::Core::Streams;

# ABSTRACT: Core library of useful streams and stream functions

use strict;
use warnings;

use utf8;
use Dallycot::Library;

BEGIN {
  require Dallycot::Library::Core::Functions;
  require Dallycot::Library::Core::Math;
}

use Promises qw(deferred collect);

use experimental qw(switch);

ns 'https://www.dallycot.io/ns/streams/1.0#';

uses 'https://www.dallycot.io/ns/functions/1.0#',
     'https://www.dallycot.io/ns/math/1.0#';

define 'last' => <<'EOD';
Y(
  (self, stream) :> (
    (?(stream...)) : self(self, stream...)
    (            ) : stream'
  )
)
EOD

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

define 'make-evens' => '() :> ({ # * 2 } @ 1..)';

define 'make-odds' => '() :> ({ # * 2 + 1 } @ 0..)';

define evens => 'make-evens()';

define odds => 'make-odds()';

define primes => <<'EOD';
  sieve := Y( (self, s) :> [ s', self(self, ~divisible-by?(_, s') % s...) ] );
  [ 1, 2, sieve(make-odds()...) ]
EOD

define 'prime-pairs' => 'primes Z primes...';

define 'twin-primes' => '{ #[2] - #[1] = 2 } % prime-pairs';

define factorials => 'factorial @ 1..';

define 'fibonacci-sequence' => <<'EOD';
  [ 1, 1, Y((self, a, b) :> [ a + b, self(self, b, a+b) ])(1, 1) ]
EOD

define 'leonardo-sequence' => <<'EOD';
  [ 1, 1, Y((self, a, b) :> [ a + b + 1, self(self, b, a + b + 1) ]) ]
EOD

define prime => '(n) :> primes[n]';
define fibonacci => '(n) :> fibonacci-sequence[n]';
define leonardo => '(n) :> leonardo-sequence[n]';

1;
