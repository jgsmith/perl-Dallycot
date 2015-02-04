package Dallycot::Channel::Terminal;

# ABSTRACT: Term::ReadLine-based i/o channel

use Moose;
extends 'Dallycot::Channel';

use Promises qw(deferred);
use Term::ReadLine;

has term => (
  is      => 'ro',
  default => sub {
    Term::ReadLine->new('Dallycot Terminal');
  }
);

sub can_send {
  my ($self) = @_;

  return defined( $self->term->OUT );
}

sub can_receive {
  my ($self) = @_;

  return defined( $self->term->IN );
}

sub has_history {1}

sub send {
  my ( $self, @stuff ) = @_;

  # For now, this is synchronous

  my $OUT = $self->term->OUT;
  return unless defined $OUT;

  print $OUT @stuff;

  return;
}

sub receive {
  my ( $self, %options ) = @_;

  my $d = deferred;

  if ( $self->can_receive ) {
    my $prompt = $options{'prompt'};
    my $line;
    if ( defined $prompt ) {
      $prompt = $prompt->value;
      $line   = $self->term->readline($prompt);
    }
    else {
      $line = $self->term->readline;
    }
    if ( defined $line ) {
      $d->resolve( Dallycot::Value::String->new($line) );
    }
    else {
      $d->resolve( Dallycot::Value::Undefined->new );
    }
  }
  else {
    $d->reject('Unable to read');
  }

  return $d->promise;
}

sub add_history {
  my ( $self, $line ) = @_;

  $self->term->addhistory( $line->value );
  return;
}

1;
