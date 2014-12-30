package Dallycot::AST::FullPlaceholder;

# ABSTRACT: A no-op placeholder in function calls

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub to_string { return "___" }

sub new {
  return bless [] => __PACKAGE__;
}

1;
