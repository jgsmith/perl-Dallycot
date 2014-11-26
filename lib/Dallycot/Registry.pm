package Dallycot::Registry;

use MooseX::Singleton;

has namespaces => (
  is => 'ro',
  isa => 'HashRef',
  default => sub { +{} }
);

sub has_assignment {
  my($self, $ns, $symbol) = @_;

  $self->namespaces->{$ns} &&
  $self->namespaces->{$ns}->has_assignment($symbol);
}

sub get_assignment {
  my($self, $namespace, $symbol) = @_;

  if($self->namespaces->{$namespace}) {
    my $ns = $self -> namespaces -> {$namespace};
    if($ns -> has_assignment($symbol)) {
      return $ns -> get_assignment($symbol);
    }
  }
}

sub has_namespace {
  my($self, $ns) = @_;

  exists $self->namespaces->{$ns};
}

sub register_namespace {
  my($self, $ns, $context) = @_;

  if(!$self->has_namespace($ns)) {
    $self->namespaces->{$ns} = $context;
  }
}

1;