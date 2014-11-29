package Dallycot::AST::Head;

use strict;
use warnings;

use utf8;
use parent 'Dallycot::AST';

sub to_string {
  my($self) = @_;

  return $self->[0]->to_string . "'"
}

sub execute {
  my($self, $engine, $d) = @_;

  $engine->execute($self->[0])->done(sub {
    my($stream) = @_;

    if($stream -> can('head')) {
      $stream->head($engine)->done(sub {
        $d -> resolve(@_);
      }, sub {
        $d -> reject(@_);
      });
    }
    else {
      $d -> reject("The head operator requires a stream-like object.");
    }
  }, sub {
    $d -> reject(@_);
  });

  return;
}

1;
