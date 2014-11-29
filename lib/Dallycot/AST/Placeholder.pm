package Dallycot::AST::Placeholder;

use strict;
use warnings;

use parent 'Dallycot::AST';

sub to_string { return "_" }

sub new {
  return bless [] => __PACKAGE__;
}

1;
