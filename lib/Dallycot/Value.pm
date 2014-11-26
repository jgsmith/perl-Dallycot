package Dallycot::Value;

use Carp qw(croak);

use v5.14;

sub type {
  my($self) = @_;

  my $type = ref $self;

  substr($type, length(__PACKAGE__)+2);
}

sub simplify { shift }

sub to_json { croak "to_json not defined for " . (ref($_[0]) || $_[0]); }

sub to_string { croak "to_string not defined for ". (ref($_[0]) || $_[0]); }

sub child_nodes { () }

sub identifiers { () }

sub length {
  my($self, $engine, $d) = @_;

  $d -> resolve($engine -> Numeric(0));
}

sub execute {
  my($self, $engine, $d) = @_;

  $d->resolve($self);
}

#-----------------------------------------------------------------------------
package Dallycot::Value::Undefined;

use parent 'Dallycot::Value::Any';

sub new { bless [] => __PACKAGE__ }

sub value { undef }

sub id { '^^Undefined' }

sub is_defined { 0 }

sub is_equal {
  my($self, $engine, $promise, $other) = @_;

  if(UNIVERSAL::isa($other, __PACKAGE__)) {
    $promise -> resolve($engine->TRUE);
  }
  else {
    $promise -> resolve($engine->FALSE);
  }
}

*is_less_or_equal = \&is_equal;
*is_greater_or_equal = \&is_equal;

sub is_less {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve($engine->FALSE);
}

*is_greater = \&is_less;

#-----------------------------------------------------------------------------
package Dallycot::Value::Numeric;

use parent 'Dallycot::Value::Any';

use Promises qw(deferred);

sub new {
  bless [ ref($_[1]) ? $_[1] : Math::BigRat->new($_[1]) ] => __PACKAGE__;
}

sub id {
  shift -> [0] -> bstr . "^^Numeric";
}

sub value {
  shift -> [0]
}

sub length {
  my($self, $engine, $d) = @_;

  $d -> resolve($engine->Numeric($self->[0]->copy->bfloor->length));
}

sub is_equal {
  my($self, $engine, $promise, $other) = @_;
  $promise -> resolve($self->value == $other->value);
}

sub is_less {
  my($self, $engine, $promise, $other) = @_;
  $promise -> resolve($self->value < $other->value);
}

sub is_less_or_equal {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve($self->value <= $other->value);
}

sub is_greater {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve($self->value > $other->value);
}

sub is_greater_or_equal {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve($self->value >= $other->value);
}

sub successor {
  my($self) = @_;

  my $d = deferred;

  $d -> resolve(bless [ $self->[0]->copy->binc ] => __PACKAGE__);

  $d -> promise;
}

sub predecessor {
  my($self) = @_;

  my $d = deferred;

  $d -> resolve(bless [ $self->[0]->copy->bdec ] => __PACKAGE__);
}

#-----------------------------------------------------------------------------
package Dallycot::Value::String;

use parent 'Dallycot::Value::Any';

use Promises qw(deferred);

sub new {
  bless [ $_[1], $_[2] || 'en' ] => __PACKAGE__;
}

sub lang { shift->[1] }

sub id {
  my($self) = @_;

  $self->[0] . "@" . $self->[1] . "^^String";
}

sub length {
  my($self, $engine, $d) = @_;

  $d -> resolve($engine->Numeric(length $self->[0]));
}

sub take_range {
  my($self, $engine, $offset, $length) = @_;

  my $d = deferred;

  if(abs($offset) > length($self->[0])) {
    $d -> resolve($self -> new('', $self->lang));
  }
  else {
    $d -> resolve($self -> new(substr($self->value, $offset-1, $length - $offset + 1), $self->lang));
  }

  $d -> promise;
}

sub drop {
  my($self, $engine, $offset) = @_;

  my $d = deferred;

  if(abs($offset) > length($self->value)) {
    $d -> resolve($self -> new('', $self->lang));
  }
  else {
    $d -> resolve($self -> new(
      substr($self -> value, $offset),
      $self -> lang
    ));
  }

  $d -> promise;
}

sub value_at {
  my($self, $engine, $index) = @_;

  my $d = deferred;

  if(!$index || abs($index) > length($self -> [0])) {
    $d -> resolve($self -> new('', $self -> [1]));
  }
  else {
    $d -> resolve($self->new(substr($self->[0], $index-1, 1), $self->[1]));
  }

  $d -> promise;
}

sub is_equal {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve(
    $self->lang eq $other->lang
    && $self->value eq $other->value
  );
}

sub is_less {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve(
    $self->lang lt $other->lang
    || $self->lang eq $other->lang
       && $self->value lt $other->value
  );
}

sub is_less_or_equal {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve(
    $self->lang lt $other->lang
    || $self->lang eq $other->lang
       && $self->value le $other->value
  );
}

sub is_greater {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve(
    $self->lang gt $other->lang
    || $self->lang eq $other->lang
       && $self->value gt $other->value
  );
}

sub is_greater_or_equal {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve(
    $self->lang gt $other->lang
    || $self->lang eq $other->lang
       && $self->value ge $other->value
  );
}


#-----------------------------------------------------------------------------
package Dallycot::Value::Boolean;

use parent 'Dallycot::Value::Any';

sub new {
  bless [ !!$_[1] ] => __PACKAGE__;
}

sub id {
  if(shift->value) {
    "true^^Boolean";
  }
  else {
    "false^^Boolean";
  }
}

sub length {
  my($self, $engine, $d) = @_;

  $d -> resolve($engine->Numeric(1));
}

sub is_equal {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve($self->value == $other->value);
}

sub is_less {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve($self->value < $other->value);
}

sub is_less_or_equal {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve($self->value <= $other->value);
}

sub is_greater {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve($self->value > $other->value);
}

sub is_greater_or_equal {
  my($self, $engine, $promise, $other) = @_;

  $promise -> resolve($self->value >= $other->value);
}

#-----------------------------------------------------------------------------
package Dallycot::Value::URI;

use parent 'Dallycot::Value::Any';

use Promises qw(deferred);

use experimental qw(switch);

sub new {
  my($class, $uri) = @_;

  $class = ref $class || $class;

  bless [ $uri ] => $class;
}

sub length {
  my($self, $engine, $d) = @_;

  $d -> resolve($engine->Numeric(length $self->[0]));
}

sub value_at {
  my($self, $engine, $index) = @_;

  my $d = deferred;

  $d -> resolve(bless [ substr($self->[0], $index-1, 1), 'en' ] => 'Dallycot::Value::String');

  $d -> promise;
}

sub execute {
  my($self, $engine, $d) = @_;

  my $url = $self->[0];

  my $resolver = Dallycot::Resolver -> instance;
  $resolver->get($url)->done(sub {
    $d -> resolve(@_);
  }, sub {
    $d -> reject(@_);
  });
}

#-----------------------------------------------------------------------------
package Dallycot::Value::TripleStore;

sub fetch_property {
  my($self, $engine, $d, $prop) = @_;

  my($base, $subject, $graph) = @$self;

  eval {
    my $pred_node = RDF::Trine::Node::Resource->new($prop);
    my @nodes = $graph -> objects($subject, $pred_node);

    my @results;

    for my $node (@nodes) {
      if($node -> is_resource) {
        push @results, bless [ $base, $node, $graph ] => __PACKAGE__;
      }
      elsif($node -> is_literal) {
        my $datatype = "String";
        if($node -> has_datatype) {
          print STDERR "node datatype: ", $node -> literal_datatype, "\n";
        }
        given($datatype) {
          when("String") {
            if($node -> has_language) {
              push @results, Dallycot::Value::String->new(
                $node -> literal_value,
                $node -> literal_value_language
              );
            }
            else {
              push @results, Dallycot::Value::String->new(
                $node -> literal_value
              );
            }
          }
          when("Numeric") {
            push @results, Dallycot::Value::Numeric->new(
              $node -> literal_value
            );
          }
        }
      }
    }

    $d -> resolve(@results);
  };
  if($@) {
    $d -> reject($@);
  }
}

#-----------------------------------------------------------------------------
package Dallycot::Value::Lambda;

use parent 'Dallycot::Value::Any';

use Promises qw(deferred collect);

use constant {
  EXPRESSION => 0,
  BINDINGS => 1,
  BINDINGS_WITH_DEFAULTS => 2,
  OPTIONS => 3,
  CLOSURE_ENVIRONMENT => 4,
  CLOSURE_NAMESPACES => 5
};

sub new {
  my $class = shift;
  $class = ref $class || $class;

  my $engine = pop;

  my $closure_context;

  if(!UNIVERSAL::isa($engine, 'Dallycot::Processor')) {
    push @_, $engine;
    $engine = undef;
  }

  my($expression, $bindings, $bindings_with_defaults, $options, $closure_environment, $closure_namespaces) = @_;

  $bindings ||= [];
  $bindings_with_defaults ||= [];
  $options ||= {};
  $closure_environment ||= {};
  $closure_namespaces ||= {};

  if($engine) {
    $closure_context = $engine->context->make_closure($expression);
    delete @{$closure_context->environment}{
      @$bindings,
      map { $_->[0] } @$bindings_with_defaults
    };
    $closure_environment = $closure_context->environment;
    $closure_namespaces = $closure_context->namespaces;
  }

  bless [ $expression, $bindings, $bindings_with_defaults, $options,
          $closure_environment, $closure_namespaces ] => $class;
}

sub id {
  '^^Lambda';
}

sub arity {
  my($self) = @_;
  my $min = scalar(@{$self->[BINDINGS]});
  my $more = scalar(@{$self->[BINDINGS_WITH_DEFAULTS]});
  if(wantarray) {
    ($min, $min+$more);
  }
  else {
    $min+$more;
  }
}

sub min_arity {
  my($self) = @_;

  scalar(@{$self->[BINDINGS]});
}

sub _arity_in_range {
  my($self, $arity, $min, $max, $promise) = @_;

  if($arity < $min || $arity > $max) {
    if($min == $max) {
      $promise -> reject("Expected $min but found $arity arguments.");
    }
    else {
      $promise -> reject("Expected $min..$max but found $arity arguments.");
    }
    return;
  }
  return 1;
}

sub _options_are_good {
  my($self, $options, $promise) = @_;

  if(%$options) {
    my @bad_options = grep {
      not exists ${$self->[OPTIONS]}{$_}
    } keys %$options;
    if(@bad_options > 1) {
      $promise -> reject("Options ".join(", ", sort(@bad_options))." are not allowed.");
      return;
    }
    elsif(@bad_options) {
      $promise -> reject("Option " .$bad_options[0]. " is not allowed.");
      return;
    }
  }
  return 1;
}

sub _is_placeholder {
  UNIVERSAL::isa($_[1], 'Dallycot::AST::Placeholder');
}

sub _get_bindings {
  my($self, $engine, @bindings) = @_;

  my($min_arity, $max_arity) = $self -> arity;
  my $arity = scalar(@bindings);

  my $d = deferred;

  my(@new_bindings, @new_bindings_with_defaults, @filled_bindings, @filled_identifiers);

  foreach my $idx (0..$min_arity-1) {
    if($self->_is_placeholder($bindings[$idx])) {
      push @new_bindings, $self->[BINDINGS][$idx];
    }
    else {
      push @filled_bindings, $bindings[$idx];
      push @filled_identifiers, $self->[BINDINGS][$idx];
    }
  }
  if($arity > $min_arity) {
    foreach my $idx ($min_arity .. $arity-1) {
      if($self->_is_placeholder($bindings[$idx])) {
        push @new_bindings_with_defaults, $self->[BINDINGS_WITH_DEFAULTS][$idx - $min_arity];
      }
      else {
        push @filled_bindings, $bindings[$idx];
        push @filled_identifiers, $self->[BINDINGS_WITH_DEFAULTS][$idx - $min_arity]->[0];
      }
    }
  }
  if($arity < $max_arity) {
    foreach my $idx ($arity..$max_arity-1) {
      push @filled_bindings, $self->[BINDINGS_WITH_DEFAULTS][$idx - $min_arity]->[1];
      push @filled_identifiers, $self->[BINDINGS_WITH_DEFAULTS][$idx - $min_arity]->[0];
    }
  }

  $engine->collect(@filled_bindings)->done(sub {
    my @binding_values = @_;
    my %bindings;
    @bindings{@filled_identifiers} = @binding_values;
    $d -> resolve(\%bindings, \@new_bindings, \@new_bindings_with_defaults);
  }, sub {
    $d -> reject(@_);
  });

  $d -> promise;
}

sub _get_options {
  my($self, $engine, $options) = @_;

  my $d = deferred;

  my @option_names = keys %$options;

  $engine->collect(
    @{$options}{@option_names}
  )->done(sub {
    my(@option_values) = @_; #map { @$_ } @_;
    my %options;

    @options{@option_names} = @option_values;
    $d -> resolve(+{
      %{$self->[OPTIONS]},
      %options
    });
  }, sub {
    $d -> reject(@_);
  });

  $d -> promise;
}

sub child_nodes { () }

sub apply {
  my($self, $engine, $options, @bindings) = @_;

  my $promise = deferred;

  my ($min_arity, $max_arity) = $self -> arity;

  my $arity = scalar(@bindings);

  if($self->_arity_in_range($arity, $min_arity, $max_arity, $promise)
     && $self->_options_are_good($options, $promise)
  ) {

    $self->_get_bindings($engine, @bindings)->done(sub {
      my($filled_bindings, $new_bindings, $new_bindings_with_defaults) = @_;

      $self->_get_options($engine, $options)->done(sub {
        my($filled_options) = @_;

        my %environment = (%{$self->[CLOSURE_ENVIRONMENT]||{}}, %$filled_bindings);

        if(@$new_bindings || @$new_bindings_with_defaults) {
          $promise -> resolve( bless [
              $self->[EXPRESSION],
              $new_bindings,
              $new_bindings_with_defaults,
              $filled_options,
              \%environment,
              $self->[CLOSURE_NAMESPACES]
            ] => __PACKAGE__
          );
        }
        else {
          my $new_engine = $engine->with_new_closure(
            { %environment, %{$filled_options} },
            $self->[CLOSURE_NAMESPACES],
          );
          $new_engine->execute($self->[EXPRESSION])->done(sub {
            $promise->resolve(@_);
          }, sub {
            $promise->reject(@_);
          });
        }
      }, sub {
        $promise -> reject(@_);
      });
    }, sub {
      $promise -> reject(@_);
    });
  }
  $promise->promise;
}


#-----------------------------------------------------------------------------
package Dallycot::Value::EmptyStream;

use parent 'Dallycot::Value::Collection';

use Promises qw(deferred);

sub new {
  bless [] => __PACKAGE__;
}

sub is_defined { 0 }

sub apply_map {
  my($self, $engine, $d, $transform) = @_;

  $d->resolve($self->new);
}

sub value_at {
  my $p = deferred;

  $p -> resolve(Dallycot::Value::Undefined->new);

  $p -> promise;
}

sub head {
  my $p = deferred;

  $p -> resolve(Dallycot::Value::Undefined->new);

  $p -> promise;
}

sub tail {
  my $p = deferred;

  $p -> resolve($_[0]->new);

  $p -> promise;
}

sub reduce {
  my($self, $engine, $start, $lambda) = @_;

  my $p = deferred;

  $p -> resolve($start);

  $p -> promise;
}

#-----------------------------------------------------------------------------
package Dallycot::Value::Stream;

use v5.14;

# RDF List
use constant {
  HEAD => 0,
  TAIL => 1,
  TAIL_PROMISE => 2
};

use parent 'Dallycot::Value::Collection';

use experimental qw(switch);

use Promises qw(deferred);

sub new {
  my($class, $head, $tail, $promise) = @_;
  bless [ $head, $tail, $promise ] => __PACKAGE__;
}

sub _resolve_tail_promise {
  my($self, $engine) = @_;
  #$engine->execute($self->[TAIL_PROMISE])->then(sub {
  $self->[TAIL_PROMISE]->apply($engine,{})->then(sub {
    my($list_tail) = @_;
    given(ref $list_tail) {
      when(__PACKAGE__) {
        $self->[TAIL] = $list_tail;
        $self->[TAIL_PROMISE] = undef;
      }
      when('Dallycot::Value::Vector') {
        # convert finite vector into linked list
        my @values = @$list_tail;
        my $point = $self;
        my $point = $self;
        while(@values) {
          $point->[TAIL] = $self->new(shift @values);
          $point = $point->[TAIL];
        }
      }
    }
  });
}

sub apply_map {
  my($self, $engine, $d, $transform) = @_;

  my $map_t = $engine->make_map($transform);

  $map_t -> apply($engine, {}, $self) -> done(sub {
    $d -> resolve(@_);
  }, sub {
    $d -> reject(@_);
  });
}

sub apply_filter {
  my($self, $engine, $d, $filter) = @_;

  my $filter_t = $engine->make_filter($filter);

  $filter_t -> apply($engine, {}, $self) -> done(sub {
    $d -> resolve(@_);
  }, sub {
    $d -> reject(@_);
  });
}

sub drop {

}

sub value_at {
  my($self, $engine, $index) = @_;
  if($index == 1) {
    return $self -> head($engine);
  }

  my $d = deferred;

  if($index < 1) {
    $d -> resolve($engine->Undefined);
  }
  else {
    # we want to keep resolving tails until we get somewhere
    $self->_walk_tail($engine, $index-1)->done(sub {
      $_[0]->head->done(sub {
        $d -> resolve(@_);
      }, sub {
        $d -> reject(@_);
      });
    }, sub {
      $d -> reject(@_);
    });
  }
  $d -> promise;
}

sub _walk_tail {
  my($self, $engine, $count) = @_;

  my $d = deferred;

  if($count > 0) {
    $self->tail($engine)->done(sub {
      my($tail) = @_;
      $tail->_walk_tail($engine, $count-1)->done(sub {
        $d -> resolve(@_);
      }, sub {
        $d -> reject(@_);
      });
    }, sub {
      $d -> reject(@_);
    });
  }
  else {
    $d -> resolve($self);
  }
  $d -> promise;
}

sub head {
  my($self, $engine) = @_;

  my $p = deferred;

  if(defined $self->[HEAD]) {
    $p -> resolve($self->[0]);
  }
  else {
    $p -> resolve(bless [] => 'Dallycot::Value::Undefined');
  }

  $p -> promise;
}

sub tail {
  my($self, $engine) = @_;

  my $p = deferred;

  if(defined $self->[TAIL]) {
    $p -> resolve($self->[TAIL]);
  }
  elsif(defined $self->[TAIL_PROMISE]) {
    $self->_resolve_tail_promise($engine)->done(sub {
      if(defined $self->[TAIL]) {
        $p -> resolve($self->[TAIL]);
      }
      else {
        $p -> reject('The tail operator expects a stream-like object.');
      }
    }, sub {
      $p -> reject(@_);
    });
  }
  else {
    $p->resolve(bless [] => 'Dallycot::Value::EmptyStream');
  }

  $p -> promise;
}

sub reduce {
  my($self, $engine, $start, $lambda) = @_;

  my $promise = deferred;

  $self->_reduce_loop($engine, $promise, $start, $lambda, $self);

  $promise->promise;
}

sub _reduce_loop {
  my($self, $engine, $promise, $start, $lambda, $stream) = @_;

  if($stream -> is_defined) {
    $stream -> head -> done(sub {
      my($head) = @_;

      $stream -> tail -> done(sub {
        my($tail) = @_;

        $lambda -> apply($engine, {}, $start, $head) -> done(sub {
          my($next_start) = @_;
          $self->_reduce_loop($engine, $promise, $next_start, $lambda, $tail);
        }, sub {
          $promise->reject(@_);
        });
      }, sub {
        $promise->reject(@_);
      });
    }, sub {
      $promise -> reject(@_);
    });
  }
  else {
    $promise -> resolve($start);
  }
}

#-----------------------------------------------------------------------------
package Dallycot::Value::Vector;

# RDF Sequence

use parent 'Dallycot::Value::Collection';

use Promises qw(deferred collect);

sub new {
  shift;
  bless \@_ => __PACKAGE__;
}

sub length {
  my($self, $engine, $d) = @_;

  $d -> resolve($engine->Number(scalar @$self));
}

sub apply_map {
  my($self, $engine, $d, $transform) = @_;

  collect(
    map { $transform -> apply($engine, {}, $_) } @$self
  )->done(sub {
    my @values = map { @$_ } @_;
    $d -> resolve(bless \@values => __PACKAGE__);
  }, sub {
    $d -> reject(@_);
  });
}

sub apply_filter {
  my($self, $engine, $d, $filter) = @_;

  collect(
    map { $filter -> apply($engine, {}, $_) } @$self
  )->done(sub {
    my(@hits) = map { $_ -> value } map { @$_ } @_;
    my @values;
    for(my $i = 0; $i < @hits; $i++) {
      push @values, $self->[$i] if $hits[$i];
    }
    $d -> resolve(bless \@values => __PACKAGE__);
  }, sub {
    $d -> reject(@_);
  });
}

sub value_at {
  my($self, $engine, $index) = @_;

  my $d = deferred;

  if($index > @$self || $index < 1) {
    $d -> resolve($engine->Undefined);
  }
  else {
    $d -> resolve($self->[$index-1]);
  }
  $d -> promise;
}

sub head {
  my($self, $engine) = @_;

  my $d = deferred;

  if(@$self) {
    $d -> resolve($self->[0]);
  }
  else {
    $d -> resolve($engine -> Undefined);
  }

  $d -> promise;
}

sub tail {
  my($self, $engine) = @_;

  my $d = deferred;

  if(@$self) {
    $d -> resolve(bless [ @$self[1..$#$self] ] => __PACKAGE__);
  }
  else {
    $d -> resolve(bless [] => __PACKAGE__);
  }

  $d -> promise;
}

sub reduce {
  my($self, $engine, $start, $lambda) = @_;

  my $promise = deferred;

  $self->_reduce_loop($engine, $promise, $start, $lambda, 0);

  $promise->promise;
}

sub _reduce_loop {
  my($self, $engine, $promise, $start, $lambda, $index) = @_;

  if($index < @$self) {
    $lambda -> apply($engine, {}, $start, $self->[$index]) -> done(sub {
      my($next_start) = @_;
      $self->_reduce_loop($engine, $promise, $next_start, $lambda, $index+1);
    }, sub {
      $promise->reject(@_);
    });
  }
  else {
    $promise -> resolve($start);
  }
}

#-----------------------------------------------------------------------------
package Dallycot::Value::Set;

# RDF Bag

use parent 'Dallycot::Value::Collection';

use Promises qw(deferred);

sub head {

}

sub tail {

}

sub reduce {

}

#-----------------------------------------------------------------------------
package Dallycot::Value::OpenRange;

# No RDF equivalent - continuous list generation of items

use parent 'Dallycot::Value::Collection';

use Promises qw(deferred);

sub type { 'Range' }

sub head {
  my($self) = @_;

  my $d = deferred;

  $d -> resolve($self->[0]);

  $d -> promise;
}

sub tail {
  my($self) = @_;

  my $d = deferred;

  $self->[0]->successor->done(sub {
    my($next) = @_;

    $d -> resolve(bless [ $next ] => __PACKAGE__);
  }, sub {
    $d -> reject(@_);
  });

  $d -> promise;
}

sub apply_map {
  my($self, $engine, $d, $transform) = @_;

  my $map_t = $engine->make_map($transform);

  $map_t -> apply($engine, {}, $self) -> done(sub {
    $d -> resolve(@_);
  }, sub {
    $d -> reject(@_);
  });
}

sub apply_filter {
  my($self, $engine, $d, $filter) = @_;

  my $filter_t = $engine->make_filter($filter);

  $filter_t -> apply($engine, {}, $self) -> done(sub {
    $d -> resolve(@_);
  }, sub {
    $d -> reject(@_);
  });
}

sub reduce {
  my($self, $engine, $start, $lambda) = @_;

  # since we're open ended, we know we can't reduce
  # might want a 'reduce until...', though we can do this
  # with filters on a sequence
  my $promise = deferred;

  $promise -> reject("An open-ended Range can not be reduced.");

  $promise -> promise;
}

#-----------------------------------------------------------------------------
package Dallycot::Value::ClosedRange;

# No RDF equivalent - finite list of items

use parent 'Dallycot::Value::Collection';

use Promises qw(deferred);

use constant {
  FIRST => 0,
  LAST => 1,
  DIRECTION => 2
};

sub reverse {
  my($self) = @_;

  my $d = deferred;

  $d -> resolve(bless [ $self->[0], $self->[1], -$self->[2] ] => __PACKAGE__);

  $d -> promise;
}

sub type { 'Range' }

sub head {
  my($self) = @_;

  my $d = deferred;

  $d -> resolve($self->[0]);

  $d -> promise;
}

sub tail {
  my($self, $engine) = @_;

  my $d = deferred;

  my $equal_p = deferred;

  $self->[0]->is_equal($engine, $equal_p, $self->[1]);
  $equal_p -> promise -> done(sub {
    my($f) = @_;

    if($f) {
      $d -> resolve(bless [] => 'Dallycot::Value::EmptyStream');
    }
    else {
      my $next_p = deferred;
      if($self->[DIRECTION] > 0) {
        $next_p = $self->[0]->successor;
      }
      else {
        $next_p = $self->[0]->predecessor;
      }
      $next_p -> done(sub {
        my($next) = @_;
        $d -> resolve(bless [
            $next,
            $self->[LAST],
            $self->[DIRECTION]
          ] => __PACKAGE__
        );
      }, sub {
        $d -> reject(@_);
      });
    }
  }, sub {
    $d -> reject(@_);
  });

  $d -> promise;
}

# We pass each value in the range through the reduction
sub reduce {
  my($self, $engine, $start, $lambda) = @_;

  if($self->[DIRECTION] < 0) {
    return $self -> reverse -> then(sub {
      $_[0]->reduce($engine, $start, $lambda);
    });
  }

  my $d = deferred;

  $self->_reduce_loop($engine, $d, $start, $lambda, $self->[0]);

  $d -> promise;
}

sub _reduce_loop {
  my($self, $engine, $promise, $start, $lambda, $value) = @_;

  my $d = deferred;
  $value->is_less_or_equal($engine, $d, $self->[1]);
  $d -> done(sub {
    my($flag) = @_;

    if($flag) {
      $lambda -> apply($engine, {}, $start, $value) -> done(sub {
        my($next_start) = @_;
        $value -> successor -> done(sub {
          my($next_value) = @_;
          $self->_reduce_loop($engine, $promise, $next_start, $lambda, $next_value);
        }, sub {
          $promise->reject(@_);
        });
      }, sub {
        $promise->reject(@_);
      });
    }
    else {
      $promise->resolve($start);
    }
  }, sub {
    $promise -> reject(@_);
  });
}

1;
