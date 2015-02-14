package Dallycot::AST::BuildList;

# ABSTRACT: Create stream-like collection with possible generator

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

use experimental qw(switch);

use Promises qw(deferred);

sub execute {
  my ( $self, $engine ) = @_;

  my $d = deferred;

  my @expressions = @$self;
  given ( scalar(@expressions) ) {
    when (0) {
      $d->resolve( Dallycot::Value::EmptyStream->new );
    }
    when (1) {
      $engine->execute( $self->[0] )->done(
        sub {
          my ($result) = @_;
          $d->resolve( Dallycot::Value::Stream->new($result) );
        },
        sub {
          $d->reject(@_);
        }
      );
    }
    default {
      my $last_expr = pop @expressions;
      my $promise;
      if ( $last_expr->isa('Dallycot::Value') ) {
        push @expressions, $last_expr;
      }
      else {
        $promise = $engine->make_lambda($last_expr);
      }
      $engine->collect(@expressions)->done(
        sub {
          my (@items) = @_;
          my $result = Dallycot::Value::Stream->new( ( pop @items ), undef, $promise );
          while (@items) {
            $result = Dallycot::Value::Stream->new( ( pop @items ), $result );
          }
          $d->resolve($result);
        },
        sub {
          $d->reject(@_);
        }
      );
    }
  }

  return $d->promise;
}

1;
