package Dallycot::AST;

use strict;
use warnings;

use utf8;
use experimental qw(switch);

use Carp qw(croak);
use Scalar::Util qw(blessed);

use Module::Pluggable
  require     => 1,
  sub_name    => '_node_types',
  search_path => 'Dallycot::AST';

use Dallycot::Value;

# use overload '""' => sub {
#   shift->to_string
# };

our @NODE_TYPES;

sub node_types {
  return @NODE_TYPES = @NODE_TYPES || shift->_node_types;
}

__PACKAGE__->node_types;

sub simplify {
  my ($self) = @_;
  return $self;
}

sub to_json {
  my ($self) = @_;

  croak "to_json not defined for " . ( blessed($self) || $self );
}

sub to_string {
  my ($self) = @_;

  croak "to_string not defined for " . ( blessed($self) || $self );
}

sub execute {
  my ( $self, $engine, $d ) = @_;

  $d->reject( ( blessed($self) || $self ) . " is not a valid operation" );
  return;
}

sub identifiers { return () }

sub child_nodes {
  my ($self) = @_;

  return grep { blessed($_) && $_->isa(__PACKAGE__) } @{$self};
}

1;
