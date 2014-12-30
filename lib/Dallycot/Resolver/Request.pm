package Dallycot::Resolver::Request;

# ABSTRACT: Manages request cycle for data resources

use Moose;

use utf8;
use Promises qw(deferred);
use URI::WithBase;
use Encode qw(decode encode);

has ua => (
  is       => 'ro',
  required => 1
);

has url => (
  is       => 'ro',
  isa      => 'Str',
  required => 1
);

has redirects => (
  is      => 'ro',
  isa     => 'Int',
  default => 10
);

has canonical_url => (
  is  => 'ro',
  isa => 'Str'
);

sub run {
  my ($self) = @_;

  my $deferred = deferred;
  my $url      = $self->url;
  my $request  = $self->ua->build_tx( GET => $url );
  $request->req->headers->accept( RDF::Trine::Parser->default_accept_header );
  my $base_uri = URI::WithBase->new( $self->url )->base || $self->url;

  $self->ua->start(
    $request,
    sub {
      my ( $ua, $response ) = @_;
      if ( $response->success ) {
        my $res = $response->res;
        if ( $res->code == 200 ) {

          # regular response - we can parse this and work with it
          # we'll load a handler based on the content type
          my $content_type_header = $res->headers->content_type;
          my @bits                = split( /;/, $content_type_header );
          my $content_type        = shift @bits;
          my %content_params = map { split(/=/, $_, 2) } @bits;
          $content_params{'charset'} //= 'ISO-8859-1';
          my $body   = $res->content->build_body;
          #$body = encode('UTF-8', decode(lc($content_params{'charset'}), $body));

          my $model;
          my $parser_class =
            eval { RDF::Trine::Parser->parser_by_media_type($content_type) };

          if($@ || !defined($parser_class) || $content_type eq 'text/html') {
            if($content_type eq 'text/html') {
              use RDF::RDFa::Parser;
              # my $options = RDF::RDFa::Parser::Config->new('xhtml', '1.1');
              my $rdfa    = RDF::RDFa::Parser->new($body, $url, RDF::RDFa::Parser::Config->tagsoup);
              $model   = $rdfa->graph;
              $deferred->resolve(
                bless [
                  $base_uri,
                  RDF::Trine::Node::Resource->new(
                    $self->canonical_url || $self->url
                  ),
                  $model
                ] => 'Dallycot::Value::TripleStore'
              );
            }
            else {
              $deferred->reject($@ || 'Unable to process content type "' + $content_type + '"');
            }
          }
          elsif ($parser_class) {
            my $parser = $parser_class->new();
            my $store  = RDF::Trine::Store::Memory->new();
            $model  = RDF::Trine::Model->new($store);
            eval {
              $parser->parse_into_model( $base_uri, $body, $model );
            };
            if(!$@) {
              $deferred->resolve(
                bless [
                  $base_uri,
                  RDF::Trine::Node::Resource->new(
                    $self->canonical_url || $self->url
                  ),
                  $model
                ] => 'Dallycot::Value::TripleStore'
              );
            }
            else {
              $deferred->reject(
                'Unable to process content type "' . $content_type . '": ' . $@
              );
            }
          }
          else {
            $deferred->reject(
              "Unable to parse content from $url: no parser for "
                . $res->headers->content_type );
          }
        }
        elsif ( $res->code == 303 || $res -> code == 302 || $res -> code == 301) {    # See Other
                                         # look for an 'Alternatives' header
          my $new_uri;
          if ( 0 >= $self->redirects ) {
            $deferred->reject("Unable to fetch $url: too many redirects");
            return;
          }

          if ( $res->headers->header('alternatives') ) {
            my $alts    = $res->headers->header('alternatives');
            my @options = $alts =~ m{
            (:?{"(.+?)"\s+([0-9.]+)\s+{type (.+?)}},?\s*)*
          }xm;
            my %types;
            while ( my ( $path, $val, $type ) = splice( @options, 0, 3 ) ) {
              $types{$type} = [ $val, $path ];
            }
            my @sorted_types =
              grep { RDF::Trine::Parser->parser_by_media_type($_) }
              sort { $types{$a}->[0] <=> $types{$b}->[0] } keys %types;

            # we'll take the first one we get
            if (@sorted_types) {
              $new_uri = $types{ $sorted_types[0] }->[1];
            }
          }
          elsif ( $res->headers->location ) {
            $new_uri = $res->headers->location;
          }
          if ($new_uri) {
            $self->new(
              ua            => $ua,
              url           => $new_uri,
              redirects     => $self->redirects - 1,
              canonical_url => $self->canonical_url
              )->run->done(
              sub { $deferred->resolve(@_); },
              sub { $deferred->reject(@_); }
              );
          }
          else {
            # we give up... nothing to see here
            $deferred->reject(
              "Unable to fetch $url: redirect with no suitable location"
            );
          }
        }
        else {
          $deferred->reject( "Unable to fetch $url: " . $res->message );
        }
      }
      else {
        my $err = $response->error;
        $deferred->reject("Unable to fetch $url: $err->{message}");
      }
    },
    sub {
      $deferred->reject(@_);
    }
  );

  return $deferred->promise;
}

1;
