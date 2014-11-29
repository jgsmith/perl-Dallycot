package Dallycot::TextResolver::Request;

use strict;
use warnings;

use Moose;

use experimental qw(switch);

use Promises qw(deferred);
use URI::WithBase;

has ua => (
  is => 'ro',
  required => 1
);

has url => (
  is => 'ro',
  isa => 'Str',
  required => 1
);

has redirects => (
  is => 'ro',
  isa => 'Int',
  default => 10
);

has canonical_url => (
  is => 'ro',
  isa => 'Str'
);

our %acceptable_types = (
  'application/xml' => 1.0,
  'application/xhtml+xml' => 1.0,
  'text/html' => 0.9,
  'text/plain' => 0.8
);

our $accept_headers = join(",", map {
  if($acceptable_types{$_} < 1) {
    $_ . ";q=" . $acceptable_types{$_};
  }
  else {
    $_;
  }
} keys %acceptable_types);

sub run {
  my($self) = @_;

  my $deferred = deferred;
  my $url = $self->url;
  my $tx = $self->ua->build_tx(GET => $url);
  $tx->req->headers->accept($accept_headers);
  my $base_uri = URI::WithBase->new($self->url)->base;

  $self->ua->start($tx, sub {
    my($ua, $tx) = @_;
    if($tx->success) {
      my $res = $tx->res;
      if($res->code == 200) {
        # regular response - we can parse this and work with it
        # we'll load a handler based on the content type
        my $content_type_header = $res->headers->content_type;
        my @bits = split(/;/, $content_type_header);
        my $content_type = shift @bits;
        my $object_type;
        given($content_type) {
          when('application/xml') {
            $object_type = 'XML';
          }
          when('application/xhtml+xml') {
            $object_type = 'HTML';
          }
          when('text/html') {
            $object_type = 'HTML';
          }
          when('text/plain') {
            $object_type = 'String';
          }
          default {
            $deferred -> reject("Unrecognized content type ($content_type)");
            return;
          }
        }
        $deferred -> resolve({
          a => $object_type,
          value => $res->content->build_body
        });
      }
      elsif($res->code == 303) { # See Other
        # look for an 'Alternatives' header
        my $new_uri;
        if(0 >= $self->redirects) {
          $deferred -> reject("Unable to fetch $url: too many redirects");
          return;
        }

        if($res->headers->header('alternatives')) {
          my $alts = $res -> headers->header('alternatives');
          my @options = $alts =~ m{
            (:?{"(.+?)"\s+([0-9.]+)\s+{type (.+?)}},?\s*)*
          }xm;
          my %types;
          while(my($path, $val, $type) = splice(@options, 0, 3)) {
            $types{$type} = [ $val, $path ];
          }
          my @sorted_types = grep {
            $acceptable_types{$_}
          } sort {
            $types{$a}->[0] <=> $types{$b}->[0]
          } keys %types;

          # we'll take the first one we get
          if(@sorted_types) {
            $new_uri = $types{$sorted_types[0]}->[1];
          }
        }
        elsif($res->headers -> location) {
          $new_uri = $res->headers->location;
        }
        if($new_uri) {
          $self->new(
            ua => $ua,
            url => $new_uri,
            redirects => $self->redirects - 1,
            canonical_url => $self->canonical_url
          )->run->done(
            sub { $deferred -> resolve(@_); },
            sub { $deferred -> reject(@_); }
          );
        }
        else {
          # we give up... nothing to see here
          $deferred -> reject("Unable to fetch $url: redirect with no suitable location");
        }
      }
      else {
        $deferred -> reject("Unable to fetch $url: " . $res->status_line);
      }
    }
    else {
      my $err = $tx->error;
      $deferred -> reject("Unable to fetch $url: $err->{message}");
    }
  }, sub {
    $deferred -> reject(@_);
  });

  return $deferred -> promise;
}

1;
