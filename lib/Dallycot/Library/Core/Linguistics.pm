package Dallycot::Library::Core::Linguistics;

# ABSTRACT: Core library of useful functions for functions

use strict;
use warnings;

use utf8;
use Dallycot::Library;

use Dallycot::Context;
use Dallycot::Parser;
use Dallycot::Processor;

use Dallycot::TextResolver;

use Lingua::StopWords;

#use Lingua::YALI::LanguageIdentifier;

use Promises qw(deferred collect);

use experimental qw(switch);

ns 'http://www.dallycot.net/ns/linguistics/1.0#';

#====================================================================
#
# Textual/Linguistic functions

define
  'stop-words' => (
  hold    => 0,
  arity   => 1,
  options => {}
  ),
  sub {
  my ( $engine, $options, $language ) = @_;

  my $d = deferred;

  if ( !$language->isa('Dallycot::Value::String') ) {
    $d->reject("stop-words expects a string argument");
  }
  else {
    my $lang  = $language->value;
    my @words = sort
      keys %{ Lingua::StopWords::getStopWords( $lang, 'UTF-8' ) || {} };
    $d->resolve( Dallycot::Value::Vector->new( map { Dallycot::Value::String->new( $_, $lang ) } @words ) );
  }

  return $d->promise;
  };

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

define
  'language-classifier' => (
  hold    => 0,
  arity   => 1,
  options => {}
  ),
  sub {
  my ( $engine, $options, $languages ) = @_;

  my $d = deferred;

  if ( !$languages->isa('Dallycot::Value::Vector') ) {
    $d->reject('language-classifier expects a vector of languages');
  }
  else {
    $d->resolve(
      bless [
        grep {$_}
        map  { $language_codes_for_classifier{ $_->value } }
        grep { $_->isa('Dallycot::Value::String') } @$languages
      ] => 'Dallycot::Library::Core::LanguageClassifier'
    );
  }

  return $d->promise;
  };

define
  'build-language-classifier-languages' => (
  hold    => 0,
  arity   => 0,
  options => {}
  ),
  sub {
  my ($engine) = @_;

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
  };

define 'language-classifier-languages' => 'build-language-classifier-languages()';

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
        $d->reject("language-classify requires a language classifier as a first argument");
        return;
      }
      if ( 'HASH' ne ref $text ) {
        $d->reject("language-classify requires a String or URI as a second argument");
        return;
      }
      given ( $text->{'a'} ) {
        when ('String') {
          my $identifier = Lingua::YALI::LanguageIdentifier->new();
          $identifier->add_language( @{ $classifier->{'languages'} } );
          my $result = $identifier->identify_string( $text->{'value'} );
          $d->resolve(
            { a        => 'String',
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
                  $d->reject( "Unable to extract text from " . $text->{'value'} );
                  return;
                }
              }
              my $worked = eval {
                my $identifier = Lingua::YALI::LanguageIdentifier->new();
                $identifier->add_language( @{ $classifier->{'languages'} } );

                # TODO: make '4096' a tunable parameter
                # algorithm takes a *long* time with large strings
                my $result = $identifier->identify_string( substr( $content, 0, 4096 ) );
                $d->resolve(
                  { a        => 'String',
                    value    => $language_codes_from_classifier{ $result->[0]->[0] },
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
          $d->reject("language-classify requires a String or URI as a second argument");
        }
      }
    }
  );

  return $d->promise;
}

define 'stop-word-languages' => <<'EOD';
[
  "da",
  "nl",
  "en",
  "fi",
  "fr",
  "de",
  "hu",
  "it",
  "no",
  "pt",
  "es",
  "sv",
  "ru"
]
EOD

1;
