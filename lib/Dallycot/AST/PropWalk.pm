use strict;
use warnings;
package Dallycot::AST::PropWalk;

use parent 'Dallycot::AST::LoopBase';

use Promises qw(collect deferred);

sub to_string {

}

sub execute {
  my($self, $engine, $d) = @_;

  my($root_expr, @steps) = @$self;

  $engine->execute($root_expr)->done(sub {
    my($root) = [ @_ ];

    if(@steps) {
      $self->_loop($engine, $d, $root, @steps);
    }
    elsif(@$root > 1) {
      $d -> resolve(bless $root => "Dallycot::Value::Set");
    }
    else {
      $d -> resolve(@$root);
    }
  }, sub {
    $d -> reject(@_);
  });
}

sub _loop {
  my($self, $engine, $d, $root, $step, @steps) = @_;

  collect(
    map {
      $step -> step($engine, $_)
    } @$root
  )->done(sub {
    my(@results) = map { @$_ } @_;
    if(@steps) {
      $self -> _loop($engine, $d, \@results, @steps);
    }
    elsif(@results > 1) {
      $d -> resolve(bless \@results => "Dallycot::Value::Set");
    }
    elsif(@results == 1) {
      $d -> resolve(@results);
    }
    else {
      $d -> resolve($engine->UNDEFINED);
    }
  }, sub {
    $d -> reject(@_);
  });
}

#-----------------------------------------------------------------------------
package Dallycot::AST::ForwardWalk;

use parent 'Dallycot::AST';

use Promises qw(deferred);

sub step {
  my($self, $engine, $root) = @_;

  my $d = deferred;

  $engine -> execute($self->[0]) -> done(sub {
    my($prop_name) = @_;
    my $prop = $prop_name -> value;
    $root -> fetch_property($engine, $d, $prop);
  }, sub {
    $d -> reject(@_);
  });

  $d -> promise;
}

#-----------------------------------------------------------------------------
package Dallycot::AST::PropertyLit;

use parent 'Dallycot::AST';

sub execute {
  my($self, $engine, $d) = @_;

  my($ns, $prop) = @$self;

  if($engine -> has_namespace($ns)) {
    my $nshref = $engine -> get_namespace($ns);
    $d -> resolve(Dallycot::Value::URI->new($nshref . $prop));
  }
  else {
    $d -> reject("Undefined namespace '$ns'");
  }
}

1;
