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

1;