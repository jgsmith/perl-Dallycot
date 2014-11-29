package Dallycot::Library::Core;

use strict;
use warnings;

use utf8;
use MooseX::Singleton;

use Dallycot::Context;
use Dallycot::Parser;
use Dallycot::Processor;
use Dallycot::TextResolver;

use Lingua::StopWords;

#use Lingua::YALI::LanguageIdentifier;

use Promises qw(deferred collect);

use experimental qw(switch);

sub initialize {
  my $context = Dallycot::Context->new;
  my $parser  = Dallycot::Parser->new;
  my $engine  = Dallycot::Processor->new(
    context  => $context,
    max_cost => 100_000_000
  );

  my $parse = $parser->parse_library(
    __PACKAGE__,
    do { local ($/) = undef; my $s = <DATA>; $s; }
  );

  return $engine->execute(@$parse)->then(
    sub {
      Dallycot::Registry->instance->register_namespace( '', $context );
    }
  );
}

sub call_function {
  my ( $self, $name, $parent_engine, @bindings ) = @_;

  my $d = deferred;

  my $method = "do_" . $name;
  if ( $self->can($method) ) {

    my $engine = Dallycot::Processor->new(
      context => Dallycot::Context->new(
        parent => $parent_engine->context
      ),
      cost     => $parent_engine->cost,
      max_cost => $parent_engine->max_cost
    );

    $self->$method( $engine, @bindings )->done(
      sub {
        $parent_engine->cost( $engine->cost );
        $d->resolve(@_);
      },
      sub {
        $parent_engine->cost( $engine->cost );
        $d->reject(@_);
      }
    );
  }
  else {
    $d->reject("undefined function called in library");
  }

  return $d->promise;
}

sub run_bindings_and_then {
  my ( $self, $engine, $d, $bindings, $cb ) = @_;

  # print STDERR "Bindings being executed: ", Data::Dumper->Dump([$bindings]);
  collect( map { $engine->execute($_) } @$bindings )->done(
    sub {
      # print STDERR "Bindings collected for cb: ", Data::Dumper->Dump([\@_]);
      my $worked = eval {
        $cb->( map { @{$_} } @_ );
        1;
      };
      if ($@) {
        $d->reject($@);
      }
      elsif ( !$worked ) {
        $d->reject("Unable to run core function.");
      }
    },
    sub {
      $d->reject(@_);
    }
  );

  return;
}

##
# eventually, this will be for string lengths
#
sub do_length {
  my ( $self, $engine, @bindings ) = @_;

  my $d = deferred;

  $self->run_bindings_and_then(
    $engine, $d,
    \@bindings,
    sub {
      my ($thing) = @_;
      my $length = 0;
      $thing->calculate_length($engine)->then(
        sub {
          $d->resolve(@_);
        },
        sub {
          $d->reject(@_);
        }
      );
    }
  );

  return $d->promise;
}

sub do_divisible_by {
  my ( $self, $engine, @bindings ) = @_;

  my $d = deferred;

  $self->run_bindings_and_then(
    $engine, $d,
    \@bindings,
    sub {
      my ( $x, $n ) = @_;
      if ( !$x->isa('Dallycot::Value::Numeric')
        || !$n->isa('Dallycot::Value::Numeric') )
      {
        $d->reject("divisible-by? expects numeric arguments");
      }
      else {
        my $xcopy = $x->value->copy();
        $xcopy->bmod( $n->value );
        $d->resolve( $engine->make_boolean( $xcopy->is_zero ) );
      }
    }
  );

  return $d->promise;
}

sub do_even_q {
  my ( $self, $engine, @bindings ) = @_;

  my $d = deferred;

  $self->run_bindings_and_then(
    $engine, $d,
    \@bindings,
    sub {
      my ($x) = @_;
      if ( !$x->isa('Dallycot::Value::Numeric') ) {
        $d->reject("even? expects a numeric argument");
      }
      else {
        $d->resolve( $engine->make_boolean( $x->[0]->is_even ) );
      }
    }
  );

  return $d;
}

sub do_odd_q {
  my ( $self, $engine, @bindings ) = @_;

  my $d = deferred;

  $self->run_bindings_and_then(
    $engine, $d,
    \@bindings,
    sub {
      my ($x) = @_;
      if ( !$x->isa('Dallycot::Value::Numeric') ) {
        $d->reject("odd? expects a numeric argument");
      }
      else {
        $d->resolve( $engine->make_boolean( $x->[0]->is_odd ) );
      }
    }
  );

  return $d->promise;
}

sub do_factorial {
  my ( $self, $engine, @bindings ) = @_;

  my $d = deferred;

  $self->run_bindings_and_then(
    $engine, $d,
    \@bindings,
    sub {
      my ($x) = @_;
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
    }
  );

  return $d->promise;
}

sub do_ceil {
  my ( $self, $engine, @bindings ) = @_;

  my $d = deferred;

  $self->run_bindings_and_then(
    $engine, $d,
    \@bindings,
    sub {
      my ($x) = @_;
      if ( !$x->isa('Dallycot::Value::Numeric') ) {
        $d->reject("ceiling expects a numeric argument");
      }
      else {
        $d->resolve( $engine->make_numeric( $x->value->copy->bceil ) );
      }
    }
  );

  return $d->promise;
}

sub do_floor {
  my ( $self, $engine, @bindings ) = @_;

  my $d = deferred;

  $self->run_bindings_and_then(
    $engine, $d,
    \@bindings,
    sub {
      my ($x) = @_;
      if ( !$x->isa('Dallycot::Value::Numeric') ) {
        $d->reject("floor expects a numeric argument");
      }
      else {
        $d->resolve( $engine->make_numeric( $x->value->copy->bfloor ) );
      }
    }
  );

  return $d->promise;
}

sub do_abs {
  my ( $self, $engine, @bindings ) = @_;

  my $d = deferred;

  $self->run_bindings_and_then(
    $engine, $d,
    \@bindings,
    sub {
      my ($x) = @_;
      if ( !$x->isa('Dallycot::Value::Numeric') ) {
        $d->reject("abs expects a numeric argument");
      }
      else {
        $d->resolve( $engine->make_numeric( $x->value->copy->babs ) );
      }
    }
  );

  return $d->promise;
}

sub do_binomial {
  my ( $self, $engine, @bindings ) = @_;

  my $d = deferred;

  $self->run_bindings_and_then(
    $engine, $d,
    \@bindings,
    sub {
      my ( $x, $y ) = @_;
      if ( !$x->isa('Dallycot::Value::Numeric')
        || !$y->isa('Dallycot::Value::Numeric') )
      {
        $d->reject("binomial-coefficient expects numeric arguments");
      }
      else {
        $d->resolve(
          $engine->make_numeric( $x->value->copy->bnok( $y->value ) ) );
      }
    }
  );

  return $d->promise;
}

#====================================================================
#
# Basic string functions

sub do_string_take {
  my ( $self, $engine, @bindings ) = @_;

  my $d = deferred;

  $self->run_bindings_and_then(
    $engine, $d,
    \@bindings,
    sub {
      my ( $string, $spec ) = @_;

      if ( !$string ) {
        $d->resolve( $engine->UNDEFINED );
      }
      elsif ( !$spec ) {
        $d->resolve( $engine->UNDEFINED );
      }
      else {
        if ( $spec->isa('Dallycot::Value::Numeric') ) {
          my $length = $spec->value->numify;
          $string->take_range( $engine, 1, $length )->done(
            sub {
              $d->resolve(@_);
            },
            sub {
              $d->reject(@_);
            }
          );
        }
        elsif ( $spec->isa('Dallycot::Value::Vector') ) {
          given ( scalar(@$spec) ) {
            when (1) {
              if ( $spec->[0]->isa('Dallycot::Value::Numeric') ) {
                my $offset = $spec->[0]->value->numify;
                $string->value_at( $engine, $offset )->done(
                  sub {
                    $d->resolve(@_);
                  },
                  sub {
                    $d->reject(@_);
                  }
                );
              }
              else {
                $d->reject("Offset must be numeric");
              }
            }
            when (2) {
              if ( $spec->[0]->isa('Dallycot::Value::Numeric')
                && $spec->[1]->isa('Dallycot::Value::Numeric') )
              {
                my ( $offset, $length ) =
                  ( $spec->[0]->value->numify, $spec->[1]->value->numify );

                $string->take_range( $engine, $offset, $length )->done(
                  sub {
                    $d->resolve(@_);
                  },
                  sub {
                    $d->reject(@_);
                  }
                );
              }
              else {
                $d->reject("string-take requires numeric offsets");
              }
            }
            default {
              $d->reject(
"string-take requires 1 or 2 numeric elements in an offset vector"
              );
            }
          }
        }
        else {
          $d->reject("Offset must be numeric or a vector of numerics");
        }
      }
    }
  );

  return $d->promise;
}

sub do_string_drop {
  my ( $self, $engine, @bindings ) = @_;

  my $d = deferred;

  $self->run_bindings_and_then(
    $engine, $d,
    \@bindings,
    sub {
      my ( $string, $spec ) = @_;

      if ( !$string ) {
        $d->resolve( $engine->UNDEFINED );
      }
      elsif ( !$spec ) {
        $d->resolve( $engine->UNDEFINED );
      }
      elsif ( $spec->isa('Dallycot::Value::Numeric') ) {
        my $offset = $spec->value->numify;
        $string->drop( $engine, $offset )->done(
          sub {
            $d->resolve(@_);
          },
          sub {
            $d->reject(@_);
          }
        );
      }
      else {
        $d->reject("string-drop requires a numeric second argument");
      }
    }
  );

  return $d->promise;
}

#====================================================================
#
# Textual/Linguistic functions

sub do_stop_words {
  my ( $self, $engine, @bindings ) = @_;

  my $d = deferred;

  $self->run_bindings_and_then(
    $engine, $d,
    \@bindings,
    sub {
      my ($language) = @_;

      if ( !$language->isa('Dallycot::Value::String') ) {
        $d->reject("stop-words expects a string argument");
      }
      else {
        my $lang = $language->value;
        my @words =
          sort
          keys %{ Lingua::StopWords::getStopWords( $lang, 'UTF-8' ) || {} };
        $d->resolve(
          Dallycot::Value::Vector->new(
            map { Dallycot::Value::String->new( $_, $lang ) } @words
          )
        );
      }
    }
  );

  return $d->promise;
}

my %language_codes_for_classifier = qw(
  af afr
  am amh
  ar ara
  an arg
  az aze
  be bel
  bn ben
  bs bos
  br bre
  bg bul
  ca cat
  cs ces
  cv chv
  co cos
  cy cym
  da dan
  de deu
  el ell
  en eng
  eo epo
  et est
  eu eus
  fo fao
  fa fas
  fi fin
  fr fra
  fy fry
  gd gla
  ga gle
  gl glg
  gu guj
  ht hat
  sh hbs
  he heb
  hi hin
  hr hrv
  hu hun
  hy hye
  io ido
  ia ina
  id ind
  is isl
  it ita
  jv jav
  ja jpn
  kn kan
  ka kat
  kk kaz
  ko kor
  ku kur
  la lat
  lv lav
  li lim
  lt lit
  lb ltz
  ml mal
  mr mar
  mk mkd
  mg mlg
  mn mon
  mi mri
  ms msa
  my mya
  ne nep
  nl nld
  nn nno
  no nor
  oc oci
  os oss
  pl pol
  pt por
  qu que
  ro ron
  ru rus
  sk slk
  sl slv
  es spa
  sq sqi
  sr srp
  su sun
  sw swa
  sv swe
  ta tam
  tt tat
  te tel
  tg tgk
  tl tgl
  th tha
  tr tur
  uk ukr
  ur urd
  uz uzb
  vi vie
  vo vol
  wa wln
  yi yid
  yo yor
  zh zho
);

my %language_codes_from_classifier = reverse %language_codes_for_classifier;

sub do_build_language_classifier {
  my ( $self, $engine, @bindings ) = @_;

  my $d = deferred;

  $self->run_bindings_and_then(
    $engine, $d,
    \@bindings,
    sub {
      my ($languages) = @_;

      if ( !$languages->isa('Dallycot::Value::Vector') ) {
        $d->reject('language-classifier expects a vector of languages');
      }
      else {
        $d->resolve(
          bless [
            grep { $_ }
            map  { $language_codes_for_classifier{ $_->value } }
            grep { $_->isa('Dallycot::Value::String') } @$languages
          ] => 'Dallycot::Library::Core::LanguageClassifier'
        );
      }
    }
  );

  return $d->promise;
}

sub do_get_available_languages_for_classifier {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  $d->resolve( Dallycot::Value::Vector->new );

  return $d->promise;

  # $d -> resolve({
  #   a => 'Vector',
  #   value => [
  #     map {
  #       +{
  #         a => 'String',
  #         value => $_,
  #         language => 'en'
  #       }
  #     } grep {
  #       $_
  #     }
  #     map {
  #       $language_codes_for_classifier{$_}
  #     } @{Lingua::YALI::LanguageIdentifier->new->get_available_languages}
  #   ]
  # })
}

sub do_classify_text_language {
  my ( $self, $engine, @bindings ) = @_;

  my $d = deferred;

  $self->run_bindings_and_then(
    $engine, $d,
    \@bindings,
    sub {
      my ( $classifier, $text ) = @_;

      if ( 'HASH' ne ref $classifier
        || $classifier->{'a'} ne 'LanguageClassifier' )
      {
        $d->reject(
          "language-classify requires a language classifier as a first argument"
        );
        return;
      }
      if ( 'HASH' ne ref $text ) {
        $d->reject(
          "language-classify requires a String or URI as a second argument");
        return;
      }
      given ( $text->{'a'} ) {
        when ('String') {
          my $identifier = Lingua::YALI::LanguageIdentifier->new();
          $identifier->add_language( @{ $classifier->{'languages'} } );
          my $result = $identifier->identify_string( $text->{'value'} );
          $d->resolve(
            {
              a        => 'String',
              value    => $language_codes_from_classifier{ $result->[0]->[0] },
              language => 'en'
            }
          );
        }
        when ('URI') {
          Dallycot::TextResolver->instance->get( $text->{'value'} )->done(
            sub {
              my ($body) = @_;
              my $content = '';
              given ( $body->{'a'} ) {
                when ('HTML') {    # content-type: text/html
                      # we want to strip out the HTML and keep only text in the
                      # <body /> outside of <script/> tags
                  my $dom = Mojo::DOM->new( $body->{'value'} );
                  $content = $dom->find('body')->all_text;
                }
                when ('String') {    # content-type: text/plain
                  $content = $body->{'value'};
                }
                when ('XML') {       # content-type: text/xml (TEI, etc.)
                  my $dom = Mojo::DOM->new->xml(1)->parse( $body->{'value'} );
                  $content = $dom->all_text;
                }
                default {
                  $d->reject(
                    "Unable to extract text from " . $text->{'value'} );
                  return;
                }
              }
              my $worked = eval {
                my $identifier = Lingua::YALI::LanguageIdentifier->new();
                $identifier->add_language( @{ $classifier->{'languages'} } );

                # TODO: make '4096' a tunable parameter
                # algorithm takes a *long* time with large strings
                my $result =
                  $identifier->identify_string( substr( $content, 0, 4096 ) );
                $d->resolve(
                  {
                    a => 'String',
                    value =>
                      $language_codes_from_classifier{ $result->[0]->[0] },
                    language => 'en'
                  }
                );
                1;
              };
              if ($@) {
                $d->reject($@);
              }
              elsif ( !$worked ) {
                $d->reject("Unable to identify language.");
              }
            },
            sub {
              $d->reject(@_);
            }
          );
        }
        default {
          $d->reject(
            "language-classify requires a String or URI as a second argument");
        }
      }
    }
  );

  return $d->promise;
}

##
#
#

1;

__DATA__

(* basic helpers *)

length(x) :> call("length", x);

divisible-by?(x,n) :> call("divisible_by", x, n);

even?(x) :> call("even_q", x);

odd?(x) :> call("odd_q", x);

upfrom := (
  upfrom_f(ff, n) :> [ n, ff(ff, n + 1) ];
  upfrom_f(upfrom_f, _)
);

downfrom := (
  downfrom_f(ff, n) :> (
    (n > 0) : [ n, ff(ff, n - 1) ]
    (n = 0) : [ 0 ]
    (     ) : [   ]
  );
  downfrom_f(downfrom_f, _)
);

range := (
  range_f(ff, m, n) :> (
    (m > n) : [ m, ff(ff, m - 1, n) ]
    (m = n) : [ m ]
    (m < n) : [ m, ff(ff, m + 1, n) ]
  );
  range_f(range_f, _, _)
);

streamLength := (
  streamLength_f(ff, s) :> (
    (?s) : 1 + ff(ff, s...)
    (  ) : 0
  );
  streamLength_f(streamLength_f, _)
);


(* Math routines *)

factorial(x) :> call("factorial", x);

floor(x) :> call("floor", x);

ceiling(x) :> call("ceil", x);

binomial-coefficient(x,y) :> call("binomial", x, y);

abs(x) :> call("abs", x);

sum(s) :> 0 << { #1 + #2 }/2 << s;

product(s) :> 1 << { #1 * #2 }/2 << s;

min(s) :> inf << { (
    (#1 < #2) : #1
    (       ) : #2
  ) } / 2 << s;

max(s) :> -inf << { (
    (#1 > #2) : #1
    (       ) : #2
  ) } / 2 << s;

count-and-sum(s) :> <0,0> << { < #1[[1]] + 1, #1[[2]] + #2 > }/2 << s;

mean(s) :> (
  cs := count-and-sum(s);
  cs[[2]] div cs[[1]]
);

differences := (
  diff_f(ff, sh, st) :> (
    (?sh and ?st) : [ sh - st', ff(ff, st', st...) ]
    (?sh        ) : [ sh ]
    (           ) : [    ]
  );

  { diff_f(diff_f, #', #...) }
);

(* basic string functions *)

string-take(string, spec) :> call("string_take", string, spec);

string-drop(string, spec) :> call("string_drop", string, spec);

(* textual routines *)

stop-words(language) :> call("stop_words", language);

stop-word-languages := [ "da", "nl", "en", "fi", "fr", "de", "hu", "it", "no", "pt", "es", "sv", "ru" ];

language-classifier(linguas) :> call("build_language_classifier", linguas);

language-classifier-languages := call("get_available_languages_for_classifier");

language-classify(classifier, text) :> call("classify_text_language", classifier, text);

(* special streams *)

evens := { # * 2 } @ 1..;

odds := { # * 2 - 1 } @ 1..;

make-evens() :> { # * 2 } @ 1..;

make-odds() :> { # * 2 - 1 } @ 1..;

(*
primes := (
  sieve_f(ff, list, s) :> (
    (?s and s' * s' < list'): [ s', ff(ff, list, s...) ]
    (?s and ?s'            ): [ s', ff(ff, list... <:: s', ~divisible-by?(_,list') % s...) ]
    (                      ): [ ]
  );
  [1, 2, sieve_f(sieve_f, <>, odds...)]
);
*)


primes := (
  sieve_f(ff, s) :> [ s', ff(ff, ~divisible-by?(_,s') % s...) ];
  [1, 2, sieve_f(sieve_f, make-odds()...)]
);

prime-pairs := primes Z primes...;

twin-primes := { #[[2]] - #[[1]] = 2 } % prime-pairs;

factorials := factorial @ 1..;

fibonacci_sequence := (
  fib_f(ff, a, b) :> [ a + b, ff(ff, b, a + b) ];
  [1, 1, fib_f(fib_f, 1, 1)]
);

leonardo_sequence := (
  leo_f(ff, a, b) :> [ a + b + 1, ff(ff, b, a + b + 1) ];
  [1, 1, leo_f(leo_f, 1, 1)]
);

prime(n) :> primes[[n]];

fibonacci(n) :> fibonacci_sequence[[n]];

leonardo(n) :> leonardo_sequence[[n]];
