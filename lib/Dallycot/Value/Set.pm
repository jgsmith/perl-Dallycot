package Dallycot::Value::Set;

# ABSTRACT: An in-memory set of unique values

use strict;
use warnings;

# RDF Bag

use utf8;
use parent 'Dallycot::Value::Collection';

use Promises qw(deferred);

sub as_text {
  my($self) = @_;

  "[" . join(", ", map { $_ -> as_text } @$self) . "]";
}

sub head {

}

sub tail {

}

sub reduce {

}

1;
