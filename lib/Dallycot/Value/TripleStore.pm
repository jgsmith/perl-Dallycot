package Dallycot::Value::TripleStore;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::Value::Any';

use experimental qw(switch);

use Promises qw(deferred);

sub calculate_length {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  $d->resolve( $engine->make_numeric( $self->[2]->size() ) );

  return $d->promise;
}

sub fetch_property {
  my ( $self, $engine, $d, $prop ) = @_;

  my ( $base, $subject, $graph ) = @$self;

  my $worked = eval {
    my $pred_node = RDF::Trine::Node::Resource->new($prop);
    my @nodes = $graph->objects( $subject, $pred_node );

    my @results;

    for my $node (@nodes) {
      if ( $node->is_resource ) {
        push @results, bless [ $base, $node, $graph ] => __PACKAGE__;
      }
      elsif ( $node->is_literal ) {
        my $datatype = "String";
        given ($datatype) {
          when ("String") {
            if ( $node->has_language ) {
              push @results,
                Dallycot::Value::String->new( $node->literal_value,
                $node->literal_value_language );
            }
            else {
              push @results,
                Dallycot::Value::String->new( $node->literal_value );
            }
          }
          when ("Numeric") {
            push @results,
              Dallycot::Value::Numeric->new( $node->literal_value );
          }
        }
      }
    }

    $d->resolve(@results);

    1;
  };
  if ($@) {
    $d->reject($@);
  }
  if ( !$worked ) {
    $d->reject("Unable to fetch $prop.");
  }

  return;
}

1;
