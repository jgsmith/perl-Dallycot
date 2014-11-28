use strict;
use warnings;
package Dallycot::AST;

use experimental qw(switch);

use Carp qw(croak);

use Dallycot::AST::PropWalk;

use Dallycot::Value;

# use overload '""' => sub {
#   shift->to_string
# };

sub simplify { shift }

sub to_json { croak "to_json not defined for " . (ref($_[0]) || $_[0]); }

sub to_string { croak "to_string not defined for ". (ref($_[0]) || $_[0]); }

sub execute {
  my($self, $engine, $d) = @_;

  $d -> reject((ref($self)||$self) . " is not a valid operation");
}

sub identifiers { () }

sub child_nodes { grep { ref($_) && UNIVERSAL::isa($_, __PACKAGE__) } @{$_[0]} }

#-----------------------------------------------------------------------------
package Dallycot::AST::Expr;

use parent 'Dallycot::AST';

sub to_json {
  {
    a => 'Expr'
  }
}

sub to_string { "" }

sub execute {
  my($self, $engine, $d) = @_;

  $d -> resolve(undef);
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Identity;

use parent 'Dallycot::AST';

sub to_string { shift->[0]->to_string }

sub execute {
  my($self, $engine, $d) = @_;

  $d -> resolve($self->[0]);
}

#-----------------------------------------------------------------------------
package Dallycot::AST::LibraryFunction;

use parent 'Dallycot::AST';

sub to_string {
  my $self = shift;

  my($parsing_library, $fname, $bindings, $options) = @$self;

  join(",", "call($parsing_library#$fname",
             (map { $_->to_string } @$bindings),
             (map { $_."->".$options->{$_}->to_string } keys %$options)
      ) . ")"
}

sub execute {
  my($self, $engine, $d) = @_;

  my($parsing_library, $fname, $bindings, $options) = @$self;

  $parsing_library -> instance -> call_function($fname, $engine, $d, @{$bindings});
}

sub child_nodes { (@{$_[0]->[2]}, values %{$_[0]->[3]}) }

#-----------------------------------------------------------------------------
package Dallycot::AST::Sequence;

use parent 'Dallycot::AST';

sub to_string {
  join("; ", map { $_ -> to_string } @{$_[0]} )
}

sub execute {
  my($self, $engine, $d) = @_;

  my $new_engine = $engine -> with_child_scope();

  $new_engine -> execute(@$self) -> done(sub {
    $d -> resolve(@_)
  }, sub {
    $d -> reject(@_)
  });
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Defined;

use parent 'Dallycot::AST';

sub to_string {
  "?(" . (shift->[0]->to_string). ")";
}

sub execute {
  my($self, $engine, $d) = @_;

  $engine->execute($self->[0])->done(sub {
    my($result) = @_;
    if(ref $result) {
      $d->resolve($result->is_defined ? $engine->TRUE : $engine->FALSE);
    }
    else {
      $d->resolve($engine->FALSE);
    }
  }, sub {
    $d -> reject(@_);
  });
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Assign;

use parent 'Dallycot::AST';

sub to_string {
  $_[0]->[0] . " := " . $_[0]->[1]->to_string
}

sub execute {
  my($self, $engine, $d) = @_;

  my $registry = Dallycot::Registry -> instance;

  if($registry->has_assignment('', $self->[0])) {
    $d -> reject('Core definitions may not be redefined.');
  }
  $engine->execute($self->[1])->then(sub {
    my($result) = @_;
    $engine -> add_assignment($self->[0], $result);
    $d -> resolve($result);
  }) -> done(sub {}, sub {
    $d -> reject(@_);
  });
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Fetch;

use parent 'Dallycot::AST';

sub new {
  my($class, $identifier) = @_;

  $class = ref $class || $class;

  bless [ $identifier ] => $class;
}

sub identifiers {
  if(@{$_[0]} == 1) {
    $_[0]->[0];
  }
  else {
    [ @{$_[0]} ]
  }
}

sub to_string { shift->[0] }

sub execute {
  my($self, $engine, $d) = @_;

  my $registry = Dallycot::Registry -> instance;
  if(@$self > 1) {
    if($engine->has_namespace($self->[0])) {
      my $ns = $engine->get_namespace($self->[0]);
      if($registry->has_namespace($ns)) {
        if($registry->has_assignment($ns, $self->[1])) {
          $d -> resolve($registry->get_assignment($ns, $self->[1]));
        }
        else {
          $d -> reject(join(":", @$self) . " is undefined.");
        }
      }
      else {
        $d -> reject("The namespace \"$ns\" is unregistered.");
      }
    }
    else {
      $d -> reject("The namespace prefix \"@{[$self->[0]]}\" is undefined.");
    }
  }
  elsif($registry->has_assignment('', $self->[0])) {
    $d->resolve($registry->get_assignment('',$self->[0]));
  }
  elsif($engine->has_assignment($self->[0])) {
    $d->resolve($engine->get_assignment($self->[0]));
  }
  else {
    $d->reject($self->[0] . " is undefined.");
  }
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Product;

use parent 'Dallycot::AST';

use constant {
  NUMERIC => ['Numeric']
};

sub to_string {
  "(" . join("*", map { $_ -> to_string } @{$_[0]}) . ")"
}

sub execute {
  my($self, $engine, $d) = @_;

  $engine->collect(
    map { [ $_, NUMERIC ] } @$self
  ) -> done( sub {
    my(@values) = map { $_->value } @_;

    my $acc = (pop @values)->copy;

    while(@values) {
      $acc *= (pop @values)
    }
    $d->resolve($engine -> make_numeric($acc));
  }, sub {
    $d -> reject(@_);
  });
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Reciprocal;

use parent 'Dallycot::AST';

use constant {
  NUMERIC => ['Numeric']
};

sub to_string { "1/(" . shift->[0]->to_string . ")" }

sub execute {
  my($self, $engine, $d) = @_;

  $engine->execute($self->[0], NUMERIC)->done(sub {
    $d -> resolve($engine->make_numeric(
      1 / ($_[0]->value)
    ));
  }, sub {
    $d -> reject(@_);
  });
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Sum;

use parent 'Dallycot::AST';

use constant {
  NUMERIC => ['Numeric']
};

sub to_string { "(" . join("+", map { $_ -> to_string } @{$_[0]}) . ")"}

sub execute {
  my($self, $engine, $d) = @_;

  $engine->collect(
    map { [ $_, NUMERIC ] } @$self
  ) -> done( sub {
    my(@values) = map { $_->value } @_;

    my $acc = (pop @values)->copy;

    while(@values) {
      $acc += (pop @values)
    }
    $d->resolve($engine -> make_numeric($acc));
  }, sub {
    $d -> reject(@_);
  });
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Negation;

use parent 'Dallycot::AST';

sub to_string { "-" . shift->[0]->to_string }

sub execute {
  my($self, $engine, $d) = @_;

  $engine->execute($self->[0], ['Numeric'])->done(sub {
    $d -> resolve($engine->make_numeric(
      -($_[0]->value)
    ));
  }, sub {
    $d -> reject(@_);
  });
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Modulus;

use parent 'Dallycot::AST';

sub to_string {
  my $self = shift;
  join(" mod ", map { $_ -> to_string } @$self);
}

sub execute {
  my($self, $engine, $d) = @_;

  my @expressions = @$self;
  $engine->execute((shift @expressions), ['Numeric'])->done(sub {
    my($left_value) = @_;

    $self -> _loop($engine, $d, $left_value, @expressions);
  }, sub {
    $d -> reject(@_);
  });
}

sub _loop {
  my($self, $engine, $d, $left_value, $right_expr, @expressions) = @_;

  if(!@expressions) {
    $engine->execute($right_expr, ['Numeric'])->done(sub {
      my($right_value) = @_;
      $d -> resolve(
        $engine->make_numeric(
          $left_value->value->copy->bmod($right_value->value)
        )
      );
    }, sub {
      $d -> reject(@_);
    });
  }
  else {
    $engine->execute($right_expr, ['Numeric']) -> done(sub {
      my($right_value) = @_;
      $left_value = $left_value->copy->bmod($right_value->value);
      if($left_value->is_zero) {
        $d->resolve($engine->make_numeric($left_value));
      }
      else {
        $self->_loop($engine, $d, $left_value, @expressions);
      }
    }, sub {
      $d->reject(@_);
    });
  }
}

#-----------------------------------------------------------------------------
package Dallycot::AST::All;

use parent 'Dallycot::AST::LoopBase';

sub new {
  my($class, @exprs) = @_;

  $class = ref $class || $class;
  bless \@exprs => $class;
}

sub _loop {
  my($self, $engine, $d, @expressions) = @_;

  if(!@expressions) {
    $d -> resolve($engine->TRUE);
  }
  else {
    $engine->execute(shift @expressions, ['Boolean'])->done(sub {
      if($_[0]->value) {
        $self->_loop($engine, $d, @expressions);
      }
      else {
        $d->resolve($engine->FALSE);
      }
    }, sub {
      $d -> reject(@_);
    });
  }
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Any;

use parent 'Dallycot::AST::LoopBase';

sub _loop {
  my($self, $engine, $d, @expressions) = @_;

  if(!@expressions) {
    $d -> resolve($engine->FALSE);
  }
  else {
    $engine->execute(shift @expressions, ['Boolean'])->done(sub {
      if($_[0]->value) {
        $d->resolve($engine->TRUE);
      }
      else {
        $self->_loop($engine, $d, @expressions);
      }
    }, sub {
      $d -> reject(@_);
    });
  }
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Equality;

use parent 'Dallycot::AST::ComparisonBase';

sub to_string {
  join(" = ", map { $_->to_string } @{$_[0]})
}

sub _compare {
  my($self, $engine, $d, $left_value, $right_value) = @_;

  $left_value->is_equal($engine, $d, $right_value);
}

#-----------------------------------------------------------------------------
package Dallycot::AST::StrictlyIncreasing;

use parent 'Dallycot::AST::ComparisonBase';

sub to_string {
  join(" < ", map { $_->to_string } @{$_[0]})
}

sub _compare {
  my($self, $engine, $d, $left_value, $right_value) = @_;

  $left_value->is_less($engine, $d, $right_value);
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Increasing;

use parent 'Dallycot::AST::ComparisonBase';

sub to_string {
  join(" <= ", map { $_->to_string } @{$_[0]})
}

sub _compare {
  my($self, $engine, $d, $left_value, $right_value) = @_;

  $left_value->is_less_or_equal($engine, $d, $right_value);
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Decreasing;

use parent 'Dallycot::AST::ComparisonBase';

sub to_string {
  join(" >= ", map { $_->to_string } @{$_[0]})
}

sub _compare {
  my($self, $engine, $d, $left_value, $right_value) = @_;

  $left_value->is_greater_or_equal($engine, $d, $right_value);
}

#-----------------------------------------------------------------------------
package Dallycot::AST::StrictlyDecreasing;

use parent 'Dallycot::AST::ComparisonBase';

sub to_string {
  join(" > ", map { $_->to_string } @{$_[0]})
}

sub _compare {
  my($self, $engine, $d, $left_value, $right_value) = @_;

  $left_value->is_greater($engine, $d, $right_value);
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Unique;

use parent 'Dallycot::AST';

sub to_string {
  join(" <> ", map { $_->to_string } @{$_[0]})
}

sub execute {
  my($self, $engine, $d) = @_;

  $engine -> collect( @$self ) -> done(sub {
    my(@values) = map { @$_ } @_;

    my @types = map { $_->type } @values;
    $engine->coerce(@values, \@types)->done(sub {
      my(@new_values) = @_;
      # now make sure values are all different
      my %seen;
      my @unique = grep { !$seen{$_->id}++ } @new_values;
      if(@unique != @new_values) {
        $d->resolve($engine->FALSE);
      }
      else {
        $d->resolve($engine->TRUE);
      }
    }, sub {
      $d -> reject(@_);
    });
  }, sub {
    $d -> reject(@_);
  });
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Condition;

use parent 'Dallycot::AST::LoopBase';

sub child_nodes {
  grep { defined } map { @{$_} } @{$_[0]}
}

sub _loop {
  my($self, $engine, $d, $condition, @expressions) = @_;

  if($condition) {
    if(defined $condition->[0]) {
      $engine->execute($condition->[0], ['Boolean'])->done(sub {
        my($flag) = @_;
        if($flag -> value) {
          $engine->execute($condition->[1])->done(sub {
            $d -> resolve(@_);
          }, sub {
            $d -> reject(@_);
          });
        }
        else {
          $self->_loop($engine, $d, @expressions);
        }
      }, sub {
        $d -> reject(@_);
      });
    }
    else {
      $engine->execute($condition->[1])->done(sub {
        $d -> resolve(@_);
      }, sub {
        $d -> reject(@_);
      });
    }
  }
  else {
    $d->resolve($engine->UNDEFINED);
  }
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Lambda;

use parent 'Dallycot::AST';

#$expression, $bindings, $bindings_with_defaults, $options
use constant {
  EXPRESSION => 0,
  BINDINGS => 1,
  BINDINGS_WITH_DEFAULTS => 2,
  OPTIONS => 3
};

sub child_nodes {
  my($self) = @_;
  $self->[EXPRESSION],
  (map { $_->[1] } @{$self->[BINDINGS_WITH_DEFAULTS]||[]}),
  #(map { $_->[0] } @{$self->[BINDINGS]||[]}),
  #@{$self->[BINDINGS]||[]},
  (values %{$self->[OPTIONS]||{}})
}

sub execute {
  my($self, $engine, $d) = @_;

  $d -> resolve(
    $engine -> make_lambda(
      @$self
    )
  );
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Apply;

use parent 'Dallycot::AST';

use constant {
  EXPRESSION => 0,
  BINDINGS => 1,
  OPTIONS => 2
};

sub new {
  my($class, $expression, $bindings, $options) = (@_, {});

  $class = ref $class || $class;
  bless [ $expression, $bindings, $options ] => $class;
}

sub child_nodes {
  my($self) = @_;

  $self->[EXPRESSION], @{$self->[BINDINGS]||[]}, values %{$self->[OPTIONS]||{}};
}

sub to_string {
  my($self) = @_;

  "(" . $self->[EXPRESSION]->to_string . ")(" . join(", ", (map { $_->to_string } @{$self->[BINDINGS]}), (map { $_." -> ".$self->[OPTIONS]->{$_}->to_string } sort keys %{$self->[OPTIONS]})) . ")";
}

sub execute {
  my($self, $engine, $d) = @_;
  $engine->execute($self->[EXPRESSION])->done(sub {
    my($lambda) = @_;
    if(!$lambda) {
      $d -> reject("Undefined value can not be a function.");
    }
    elsif($lambda -> can('apply')) {
      $lambda -> apply($engine, {%{$self->[OPTIONS]}}, @{$self->[BINDINGS]}) -> done(sub {
        $d -> resolve(@_);
      }, sub {
        $d -> reject(@_);
      });
    }
    else {
      $d->reject("Value of type " . $lambda->type . " can not be used as a function.");
    }
  }, sub {
    $d -> reject(@_);
  });
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Reduce;

use parent 'Dallycot::AST';

use constant {
  LAMBDA => ['Lambda'],
  STREAM => ['Collection'],
};

sub execute {
  my($self, $engine, $d) = @_;

  $engine->collect(
    $self->[0],
    [ $self->[1], LAMBDA ],
    [ $self->[2], STREAM ]
  )->done(sub {
    my($start, $lambda, $stream) = @_;
    $stream -> reduce($engine, $start, $lambda) -> done(sub {
      $d -> resolve(@_);
    }, sub {
      $d -> reject(@_);
    });
  }, sub {
    $d -> reject(@_);
  });
}

#-----------------------------------------------------------------------------
package Dallycot::AST::BuildRange;

use parent 'Dallycot::AST';

use Promises qw(deferred);

sub execute {
  my($self, $engine, $d) = @_;

  if(@$self == 1 || !defined($self->[1])) { # semi-open range
    $engine -> execute($self->[0])->done(sub {
      $d -> resolve( bless [
          @_
        ] => 'Dallycot::Value::OpenRange'
      );
    }, sub {
      $d -> reject(@_);
    });
  }
  else {
    $engine->collect(@$self)->done(sub {
      my($left_value, $right_value) = @_;

      my $less_p = deferred;
      $left_value->is_less($engine, $less_p, $right_value);

      $less_p -> promise -> done(sub {
        my($f) = @_;

        $d -> resolve( bless [
            $left_value, $right_value, $f ? 1 : -1
          ] => 'Dallycot::Value::ClosedRange'
        );
      }, sub {
        $d -> reject(@_);
      });
    }, sub {
      $d -> reject(@_);
    });
  }
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Zip;

use parent 'Dallycot::AST';

use Promises qw(collect);

use List::Util qw(max);
use List::MoreUtils qw(all any each_array);

sub to_string {
  '(' . join(' Z ', map { $_ -> to_string } @{$_[0]}) . ')'
}

sub execute {
  my($self, $engine, $d) = @_;

  # produce a vector with the head of each thing
  # then a tail promise for the rest
  # unless we're all vectors, in which case zip everything up now!
  if(any { $_ -> isa('Dallycot::AST') } @$self) {
    $engine -> collect(@$self) -> done(sub {
      my $newself = bless \@_ => __PACKAGE__;
      $newself -> execute($engine, $d);
    }, sub {
      $d -> reject(@_);
    });
  }
  elsif(all { $_ -> isa('Dallycot::Value::Vector') } @$self) {
    # all vectors
    my $it = each_arrayref(@$self);
    my @results;
    while(my @vals = $it->()) {
      push @results, bless \@vals => 'Dallycot::Value::Vector';
    }
    $d->resolve(bless \@results => 'Dallycot::Value::Vector');
  }
  elsif(all { $_ -> isa('Dallycot::Value::String') } @$self) {
    # all strings
    my @sources = map { \{$_->value} } @$self;
    my $length = max(map { length $$_ } @sources);
    my @results;
    for(my $idx = 0; $idx < $length; $idx ++) {
      my $s = join("", map { substr($$_, $idx, 1) } @sources);
      push @results, Dallycot::Value::String->new($s);
    }
    $d->resolve(bless \@results => 'Dallycot::Value::Vector');
  }
  else {
    collect(
      map { $_ -> head($engine) } @$self
    )->done(sub {
      my(@heads) = map { @$_ } @_;
      collect(
        map { $_ -> tail($engine) } @$self
      )->done(sub {
        my(@tails) = map { @$_ } @_;
        my $r;
        $d -> resolve(
          $r = bless [
            (bless \@heads => 'Dallycot::Value::Vector'),

            undef,

            Dallycot::Value::Lambda->new(
              (bless \@tails => __PACKAGE__),
              [],
              [],
              {}
            )
          ] => 'Dallycot::Value::Stream'
        );
      }, sub {
        $d -> reject(@_);
      })
    }, sub {
      $d -> reject(@_);
    });
  }
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Tail;

use parent 'Dallycot::AST';

sub to_string {
  $_[0]->[0]->to_string . '...'
}

sub execute {
  my($self, $engine, $d) = @_;

  $engine->execute($self->[0])->done(sub {
    my($stream) = @_;

    if($stream -> can('tail')) {
      $stream->tail($engine)->done(sub {
        $d->resolve(@_);
      }, sub {
        $d->reject(@_);
      });
    }
    else {
      $d -> reject("The tail operator requires a stream-like object.");
    }
  }, sub {
    $d -> reject(@_);
  });
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Head;

use parent 'Dallycot::AST';

sub to_string {
  $_[0]->[0]->to_string . "'"
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
}

#-----------------------------------------------------------------------------
package Dallycot::AST::TypePromotion;

use parent 'Dallycot::AST';

sub to_string {
  my @bits = @{$_[0]};

  my $expr = shift @bits;

  join("^^", $expr->to_string, @bits);
}

#-----------------------------------------------------------------------------
package Dallycot::AST::BuildList;

use parent 'Dallycot::AST';

sub execute {
  my($self, $engine, $d) = @_;

  my @expressions = @$self;
  given(scalar(@expressions)) {
    when(0) {
      $d -> resolve(Dallycot::Value::EmptyStream->new);
    }
    when(1) {
      $engine->execute($self->[0])->done(sub {
        my($result) = @_;
        $d -> resolve(Dallycot::Value::Stream->new($result));
      }, sub {
        $d -> reject(@_);
      });
    }
    default {
      my $last_expr = pop @expressions;
      my $promise;
      if($last_expr -> isa('Dallycot::Value')) {
        push @expressions, $last_expr;
      }
      else {
        $promise = $engine->make_lambda($last_expr);
      }
      $engine->collect(@expressions)->done(sub {
        my(@items) = @_;
        my $result = Dallycot::Value::Stream->new((pop @items), undef, $promise);
        while(@items) {
          $result = Dallycot::Value::Stream->new((pop @items), $result);
        }
        $d -> resolve($result);
      }, sub {
        $d -> reject(@_);
      });
    }
  }
}

#-----------------------------------------------------------------------------
package Dallycot::AST::BuildVector;

use parent 'Dallycot::AST';

sub execute {
  my($self, $engine, $d) = @_;

  $engine->collect(@$self)->done(sub {
    my(@bits) = @_;

    $d -> resolve(bless \@bits => 'Dallycot::Value::Vector');
  }, sub {
    $d -> reject(@_);
  });
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Placeholder;

use parent 'Dallycot::AST';

sub to_string { "_" }

sub new {
  bless [] => __PACKAGE__;
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Compose;

use parent 'Dallycot::AST';

sub execute {
  my($self, $engine, $d) = @_;

  $engine->collect(@$self)->done(sub {
    my(@functions) = @_;
    if(grep { !$_->isa('Dallycot::Value::Lambda') } @functions) {
      $d -> reject("All terms in a function composition must be lambdas");
    }
    elsif(grep { 1 != $_->min_arity } @functions) {
      $d -> reject("All lambdas in a function composition must have arity 1");
    }
    else {
      $d -> resolve($engine -> compose_lambdas(@functions));
    }
  }, sub {
    $d -> reject(@_);
  });
}

#-----------------------------------------------------------------------------
package Dallycot::AST::BuildMap;

use parent 'Dallycot::AST';

sub execute {
  my($self, $engine, $d) = @_;

  $engine->collect(@$self)->done(sub {
    my(@functions) = @_;
    my $stream = pop @functions;
    if(grep { !$_->isa('Dallycot::Value::Lambda') } @functions) {
      $d -> reject("All but the last term in a mapping must be lambdas.");
    }
    elsif(grep { 1 != $_->min_arity } @functions) {
      $d -> reject("All lambdas in a mapping must have arity 1.");
    }
    else {
      if($stream -> isa('Dallycot::Value::Lambda')) {
        # we really just have a composition
        push @functions, $stream;
        my $transform = $engine->compose_lambdas(@functions);
        $d -> resolve($engine->make_map($transform));
      }
      else {
        my $transform = $engine->compose_lambdas(@functions);

        $stream -> apply_map($engine, $d, $transform);
      }
    }
  }, sub {
    $d -> reject(@_);
  });
}

#-----------------------------------------------------------------------------
package Dallycot::AST::BuildFilter;

use parent 'Dallycot::AST';

sub execute {
  my($self, $engine, $d) = @_;

  $engine->collect(@$self)->done(sub {
    my(@functions) = @_;
    my $stream = pop @functions;
    if(grep { !$_->isa('Dallycot::Value::Lambda') } @functions) {
      $d -> reject("All but the last term in a filter must be lambdas.");
    }
    elsif(grep { 1 != $_->min_arity } @functions) {
      $d -> reject("All lambdas in a filter must have arity 1.");
    }
    else {
      if($stream -> isa('Dallycot::Value::Lambda')) {
        # we really just have a composition
        push @functions, $stream;
        my $filter = $engine->compose_filters(@functions);
        $d -> resolve($engine->make_filter($filter));
      }
      else {
        my $filter = $engine->compose_filters(@functions);

        $stream -> apply_filter($engine, $d, $filter);
      }
    }
  }, sub {
    $d -> reject(@_);
  });
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Index;

use parent 'Dallycot::AST';

sub execute {
  my($self, $engine, $d) = @_;

  my @expressions = @$self;

  if(@expressions) {
    $engine->execute(shift @expressions) -> done(sub {
      my($root) = @_;
      $self -> _do_next_index($engine, $d, $root, @expressions);
    }, sub {
      $d->reject(@_);
    });
  }
  else {
    $d -> reject('missing expressions');
  }
}

sub _do_next_index {
  my($self, $engine, $d, $root, $index_expr, @indices) = @_;

  if($index_expr) {
    $engine->execute($index_expr)->done(sub {
      my($index) = @_;

      if($index->isa('Dallycot::Value::Numeric')) {
        $index = $index->value;
      }
      else {
        $d -> reject("Vector indices must be numeric");
        return;
      }
      $root -> value_at($engine, $index) -> done(sub {
        $self->_do_next_index($engine, $d, $_[0], @indices);
      }, sub {
        $d -> reject(@_);
      });
    }, sub {
      $d -> reject(@_);
    });
  }
  else {
    $d -> resolve($root);
  }
}

#-----------------------------------------------------------------------------
package Dallycot::AST::Invert;

use parent 'Dallycot::AST';

sub new {
  my($class, $expr) = @_;

  $class = ref $class || $class;
  bless [ $expr ] => $class;
}

sub execute {
  my($self, $engine, $d) = @_;

  $engine->execute($self->[0])->done(sub {
    my($res) = @_;

    if($res->isa('Dallycot::Value::Boolean')) {
      $d -> resolve($engine->make_boolean(!$res->value));
    }
    elsif($res->isa('Dallycot::Value::Lambda')) {
      $d -> resolve(
        Dallycot::Value::Lambda->new(
          Dallycot::AST::Invert->new($res->[0]),
          @$res[1,2,3,4,5]
        )
      );
    }
    else {
      $d -> resolve($engine->make_boolean(!$res->is_defined));
    }
  }, sub {
    $d -> reject(@_);
  });
}

1;
