package Dallycot::AST::TypePromotion;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub to_string {
  my($self) = @_;
  my @bits = @{$self};

  my $expr = shift @bits;

  return join("^^", $expr->to_string, @bits);
}

1;
