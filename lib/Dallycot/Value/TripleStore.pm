use strict;
use warnings;
package Dallycot::Value::TripleStore;

use parent 'Dallycot::Value::Any';

use experimental qw(switch);

sub fetch_property {
  my($self, $engine, $d, $prop) = @_;

  my($base, $subject, $graph) = @$self;

  eval {
    my $pred_node = RDF::Trine::Node::Resource->new($prop);
    my @nodes = $graph -> objects($subject, $pred_node);

    my @results;

    for my $node (@nodes) {
      if($node -> is_resource) {
        push @results, bless [ $base, $node, $graph ] => __PACKAGE__;
      }
      elsif($node -> is_literal) {
        my $datatype = "String";
        if($node -> has_datatype) {
          print STDERR "node datatype: ", $node -> literal_datatype, "\n";
        }
        given($datatype) {
          when("String") {
            if($node -> has_language) {
              push @results, Dallycot::Value::String->new(
                $node -> literal_value,
                $node -> literal_value_language
              );
            }
            else {
              push @results, Dallycot::Value::String->new(
                $node -> literal_value
              );
            }
          }
          when("Numeric") {
            push @results, Dallycot::Value::Numeric->new(
              $node -> literal_value
            );
          }
        }
      }
    }

    $d -> resolve(@results);
  };
  if($@) {
    $d -> reject($@);
  }
}

1;
