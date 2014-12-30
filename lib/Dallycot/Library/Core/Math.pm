package Dallycot::Library::Core::Math;

# ABSTRACT: Core library of useful math functions

use strict;
use warnings;

use utf8;
require Dallycot::Library::Core::Functions;

use Dallycot::Library;

use Promises qw(deferred collect);

use experimental qw(switch);

ns 'https://www.dallycot.io/ns/math/1.0#';

uses 'https://www.dallycot.io/ns/functions/1.0#';

define
  'divisible-by?' => (
    hold    => 0,
    arity   => 2,
    options => {},
  ),
  sub {
    my ( $engine, $options, $x, $n ) = @_;

    my $d = deferred;

    if (   !$x->isa('Dallycot::Value::Numeric')
        || !$n->isa('Dallycot::Value::Numeric') )
    {
        $d->reject("divisible-by? expects numeric arguments");
    }
    else {
        my $xcopy = $x->value->copy();
        $xcopy->bmod( $n->value );
        $d->resolve( Dallycot::Value::Boolean->new( $xcopy->is_zero ) );
    }

    return $d->promise;
  };

define
  'even?' => (
    hold    => 0,
    arity   => 1,
    options => {}
  ),
  sub {
    my ( $engine, $options, $x ) = @_;

    my $d = deferred;

    if ( !$x->isa('Dallycot::Value::Numeric') ) {
        $d->reject("even? expects a numeric argument");
    }
    else {
        $d->resolve( Dallycot::Value::Boolean->new( $x->[0]->is_even ) );
    }

    return $d;
  };

define
  'odd?' => (
    hold    => 0,
    arity   => 1,
    options => {}
  ),
  sub {
    my ( $engine, $options, $x ) = @_;

    my $d = deferred;

    if ( !$x->isa('Dallycot::Value::Numeric') ) {
        $d->reject("odd? expects a numeric argument");
    }
    else {
        $d->resolve( Dallycot::Value::Boolean->new( $x->[0]->is_odd ) );
    }

    return $d->promise;
  };

define
  factorial => (
    hold    => 0,
    arity   => 1,
    options => {}
  ),
  sub {
    my ( $engine, $options, $x ) = @_;

    my $d = deferred;

    if ( !$x->isa('Dallycot::Value::Numeric') ) {
        $d->reject("factorial expects a numeric argument");
    }
    elsif ( $x->value->is_int ) {
        $d->resolve( $engine->make_numeric( $x->value->copy()->bfac() ) );
    }
    else {
        # TODO: handle non-integer arguments to gamma function
        $d->resolve( $engine->UNDEFINED );
    }

    return $d->promise;
  };

define
  ceil => (
    hold    => 0,
    arity   => 1,
    options => {}
  ),
  sub {
    my ( $engine, $options, $x ) = @_;

    my $d = deferred;

    if ( !$x->isa('Dallycot::Value::Numeric') ) {
        $d->reject("ceiling expects a numeric argument");
    }
    else {
        $d->resolve( $engine->make_numeric( $x->value->copy->bceil ) );
    }

    return $d->promise;
  };

define
  floor => (
    hold    => 0,
    arity   => 1,
    options => {}
  ),
  sub {
    my ( $engine, $options, $x ) = @_;

    my $d = deferred;

    if ( !$x->isa('Dallycot::Value::Numeric') ) {
        $d->reject("floor expects a numeric argument");
    }
    else {
        $d->resolve( $engine->make_numeric( $x->value->copy->bfloor ) );
    }

    return $d->promise;
  };

define
  abs => (
    hold    => 0,
    arity   => 1,
    options => {}
  ),
  sub {
    my ( $engine, $options, $x ) = @_;

    my $d = deferred;

    if ( !$x->isa('Dallycot::Value::Numeric') ) {
        $d->reject("abs expects a numeric argument");
    }
    else {
        $d->resolve( $engine->make_numeric( $x->value->copy->babs ) );
    }

    return $d->promise;
  };

define
  binomial => (
    hold    => 0,
    arity   => 2,
    options => {}
  ),
  sub {
    my ( $engine, $options, $x, $y ) = @_;

    my $d = deferred;

    if (   !$x->isa('Dallycot::Value::Numeric')
        || !$y->isa('Dallycot::Value::Numeric') )
    {
        $d->reject("binomial-coefficient expects numeric arguments");
    }
    else {
        $d->resolve(
            $engine->make_numeric( $x->value->copy->bnok( $y->value ) ) );
    }

    return $d->promise;
  };

define sum => 'foldl(0, { #1 + #2 }/2, _)';

define product => 'foldl(1, { #1 * #2 }/2, _)';

define min => <<'EOD';
  foldl1({(
    (#1 < #2) : #1
    (       ) : #2
  )}/2, _)
EOD

define max => <<'EOD';
  foldl1({(
    (#1 > #2) : #1
    (       ) : #2
  )}/2, _)
EOD

define 'weighted-count-and-sum' => <<'EOD';
  foldl( <0,0>, (
    (pad, element) :>
      <pad[1] + element[1], pad[2] + element[1] * element[2]>
  ), _)
EOD

define 'count-and-sum' => <<'EOD';
  foldl( <0,0>, (
    (pad, element) :>
      < pad[1] + 1, pad[2] + element >
  ), _)
EOD

define mean => <<'EOD';
  (s) :> { #[2] div #[1] } @ count-and-sum(s)
EOD

define differences => <<'EOD';
diff := Y(
  (self, sh, st) :> (
    (?sh and ?st) : [ sh - st', self(self, st', st...) ]
    (?sh        ) : [ sh ]
    (           ) : [    ]
  )
);
{ diff(#', #...) }
EOD

define gcd => <<'EOD';
Y(
  (self, a, b) :> (
    (a = 0) : b
    (b = 0) : a
    (a > b) : self(self, a mod b, b)
    (     ) : self(self, a, b mod a)
  )
)
EOD

1;
