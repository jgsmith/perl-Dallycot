package Dallycot::Channel;

use Moose;
use Carp qw(croak);

sub can_send { 0 }
sub can_receive { 0 }

sub send {
  my($self, @content) = @_;

  # This needs to be written for an output channel
  my $class = ref $self || $self;
  croak "send() is not implemented for $class";
}

sub receive {
  my($self) = @_;

  # This also needs to be written for an input channel
  # should return a promise that will be fulfilled with the
  # input when it arrives
  my $class = ref $self || $self;
  croak "receive() is not implemented for $class";
}

1;
