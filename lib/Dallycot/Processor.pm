package Dallycot::Processor;

# ABSTRACT: Run compiled Dallycot code.

use v5.20;

use Moose;

use Promises qw(deferred);

use experimental qw(switch);

use Dallycot::Context;
use Dallycot::Registry;
use Dallycot::Resolver;
use Dallycot::Value;
use Dallycot::AST;

use Math::BigRat try => 'GMP';

has context => (
  is => 'ro',
  isa => 'Dallycot::Context',
  # handles => qw[
  #   has_assignment
  #   get_assignment
  #   add_assignment
  #   has_namespace
  #   get_namespace
  # ],
  default => sub {
    Dallycot::Context -> new
  }
);

has max_cost => (
  is => 'rw',
  isa => 'Int',
  default => 100_000
);

has cost => (
  is => 'rw',
  isa => 'Int',
  default => 0
);

has parent => (
  is => 'ro',
  predicate => 'has_parent',
  isa => __PACKAGE__
);

sub has_assignment { shift -> context -> has_assignment(@_) }
sub get_assignment { shift -> context -> get_assignment(@_) }
sub add_assignment { shift -> context -> add_assignment(@_) }
sub has_namespace { shift -> context -> has_namespace(@_) }
sub get_namespace { shift -> context -> get_namespace(@_) }

sub add_cost {
  my($self, $delta) = @_;

  if($self -> has_parent) {
    $self -> parent -> add_cost($delta);
  }
  else {
    $self -> cost($self -> cost + $delta);
    $self -> cost > $self -> max_cost;
  }
}

sub with_child_scope {
  my($self) = @_;

  $self -> new(
    parent => $self,
    context => $self -> context -> new(
      parent => $self -> context
    )
  );
}

sub with_new_closure {
  my($self, $environment, $namespaces) = @_;

  $self -> new(
    parent => $self,
    context => $self -> context -> new(
      environment => $environment,
      namespaces => $namespaces
    )
  );
}

sub collect {
  my $self = shift;

  Promises::collect(
    map {
      my $expr = $_;
      if('ARRAY' eq ref $expr) {
        $self->execute(@$expr);
      }
      else {
        $self->execute($expr);
      }
    } @_
  )->then(sub {
    map { @$_ } @_;
  });
}

# for now, just returns the original values
sub coerce {
  my($self, $a, $b, $atype, $btype) = @_;

  my $d = deferred;

  $d -> resolve($a, $b);

  $d -> promise;
}

sub Lambda {
  my($self, $expression, $bindings, $bindings_with_defaults, $options) = @_;

  $bindings ||= [];
  $bindings_with_defaults ||= [];
  $options ||= {};

  Dallycot::Value::Lambda->new(
    $expression, $bindings, $bindings_with_defaults, $options,
    $self
  );
}

sub Boolean {
  Dallycot::Value::Boolean->new($_[1]);
}

sub Numeric {
  Dallycot::Value::Numeric->new($_[1]);
}

sub String {
  shift;
  Dallycot::Value::String->new(@_);
}

sub Vector {
  shift;
  Dallycot::Value::Vector->new(@_);
}

sub Undefined {
  Dallycot::Value::Undefined->new;
}

use constant TRUE => Boolean(undef,1);
use constant FALSE => Boolean(undef,'');

sub execute_all {
  my $self     = shift;
  my $deferred = shift;

  $self->_execute_loop($deferred, ['Any'], @_);
}

sub _execute_loop {
  my ($self,$deferred, $expected_types, $stmt, @stmts) = @_;

  if ( !@stmts ) {
    $self -> _execute($expected_types, $stmt)
          -> done(
            sub { $deferred -> resolve(@_); },
            sub { $deferred -> reject(@_); }
          );
    return;
  }
  $self -> _execute(['Any'], $stmt)
        -> done(
          sub { $self -> _execute_loop($deferred, $expected_types, @stmts) },
          sub { $deferred -> reject(@_); }
        );
}


sub _execute {
  my($self, $expected_types, $ast) = @_;

  my $d = deferred;
  if($self -> add_cost(1)) {
    $d -> reject("Exceeded maximum evaluation cost");
  }
  else {
    $ast -> execute($self, $d);
  }
  $d -> promise;
}

sub execute {
  my($self, $ast, @ast) = @_;

  my @expected_types = ('Any');

  if(@ast) {
    my $last = pop @ast;

    if('ARRAY' eq ref $last) {
      @expected_types = @$last;
    }
    else {
      push @ast, $last;
    }
  }

  my $d = deferred;

  if(@ast) {
    $self->_execute_loop($d, \@expected_types, $ast, @ast);
  }
  else {
    $self->_execute(\@expected_types, $ast)->done(
      sub { $d -> resolve(@_); },
      sub { $d -> reject(@_); }
    );
  }
  $d -> promise;
}

sub stream_to_vector {
  my($self, $d, $stream, $vector_values) = (@_, []);

  my $d_head = deferred;
  $self -> _get_head($stream, $d_head);
  $d_head->done(sub {
    my($head) = @_;
    if(defined $head) {
      push @{$vector_values}, $head;
      my $d_tail = deferred;
      $self -> _get_tail($stream, $d_tail);
      $d_tail->done(sub {
        my($tail) = @_;
        if(defined $tail) {
          $self -> stream_to_vector($d, $tail, $vector_values);
        }
        else {
          $d -> resolve({
            a => 'Vector',
            value => $vector_values
          });
        }
      }, sub {
        $d -> reject(@_);
      });
    }
  }, sub {
    $d -> reject(@_);
  });
}

sub doBuildRange {
  my($self, $json, $d) = @_;

  if($json->{'expressions'}) {
    my $arity = scalar(@{$json->{'expressions'}});
    if($arity < 1 || $arity > 2) {
      $self -> _reject($d, 'wrong number of expressions');
    }
    else {
      collect(
        map { $self -> execute($_) } @{$json->{'expressions'}}
      )->done(
        sub {
          my(@points) = map { @$_ } @_;
          if(grep { 'HASH' ne ref $_ or $_->{'a'} ne 'Numeric' or !$_->{'value'}->is_int} @points) {
            $d -> reject('Ranges require integer start and/or end');
          }
          elsif($arity == 1) {
            my $next = $points[0]->{value}->copy->binc;
            $d -> resolve({
              a => 'List',
              head => $points[0],
              tail_promise => {
                a => 'LambdaWithClosure',
                closure => {
                  environment => {},
                  namespaces => {},
                },
                bindings => [],
                bindings_with_defaults => [],
                options => {},
                expression => {
                  a => 'Range',
                  start => $next,
                  step => Math::BigRat->bone
                }
              }
            });
          }
          else {
            if($points[0]->{value} == $points[1]->{value}) {
              $d -> resolve({
                a => 'List',
                head => $points[0]
              });
            }
            else {
              my $next = $points[0]->{value}->copy;
              my $inc;
              if($points[0]->{value} > $points[1]->{value}) {
                $inc = Math::BigRat->bone('-');
                $next -> bdec;
              }
              else {
                $inc = Math::BigRat->bone;
                $next -> binc;
              }

              $d -> resolve({
                a => 'List',
                head => $points[0],
                tail_promise => {
                  a => 'LambdaWithClosure',
                  closure => {
                    environment => {},
                    namespaces => {},
                  },
                  bindings => [],
                  bindings_with_defaults => [],
                  options => {},
                  expression => {
                    a => 'Range',
                    start => $next,
                    end => $points[1]->{value},
                    step => Math::BigRat->new($inc)
                  }
                }
              });
            }
          }
        },
        sub {
          $d -> reject(@_);
        }
      );
    }
  }
  else {
    $self -> _reject($d, 'missing expressions');
  }
}

sub doRange {
  my($self, $json, $d) = @_;

  if(defined $json -> {'start'}) {
    if(defined $json->{'end'}) {
      my $step = $json->{'step'} || Math::BigRat->bone;
      my $next = $json->{'start'}->copy;
      $next->badd($step);
      my $finished = 0;
      if($step -> is_pos) {
        if($next > $json->{'end'}) {
          $finished = 1;
        }
      }
      elsif($next < $json->{'end'}) {
        $finished = 1;
      }
      if($finished) {
        $d->resolve({
          a => 'List',
          head => {
            a => 'Numeric',
            value => $json->{'start'}
          }
        });
      }
      else {
        $d -> resolve({
          a => 'List',
          head => {
            a => 'Numeric',
            value => $json->{'start'}
          },
          tail_promise => {
            a => 'LambdaWithClosure',
            closure => {
              environment => {},
              namespaces => {},
            },
            bindings => [],
            bindings_with_defaults => [],
            options => {},
            expression => {
              a => 'Range',
              start => $next,
              end => $json->{'end'},
              step => $step
            }
          }
        });
      }
    }
    else {
      my $step = $json->{'step'} || Math::BigRat->bone;
      my $next = $json->{'start'}->copy;
      $next -> badd($step);
      $d -> resolve({
        a => 'List',
        head => {
          a => 'Numeric',
          value => $json->{'start'},
        },
        tail_promise => {
          a => 'LambdaWithClosure',
          closure => {
            environment => {},
            namespaces => {},
          },
          bindings => [],
          bindings_with_defaults => [],
          options => {},
          expression => {
            a => 'Range',
            start => $next,
            step => $step
          }
        }
      });
    }
  }
  else {
    $self->_reject($d, 'missing range start');
  }
}

sub doCons {
  my($self, $json, $d) = @_;

  if($json->{'expressions'}) {
    collect(
      map { $self -> execute($_) } @{$json->{'expressions'}}
    )->done(sub {
      my(@things) = map { @$_ } @_;

      if(grep { 'HASH' eq ref $_ && $_->{'a'} eq 'List' } @things) {
        # we have streams...

      }
      # we expect the last item to be a List
    }, sub {
      $d -> reject(@_);
    });
  }
}

sub doPush {
  my($self, $json, $d) = @_;

  if($json->{'expressions'}) {
    collect(
      map { $self -> execute($_) } @{$json->{'expressions'}}
    )->done(sub {
      my(@things) = map { @$_ } @_;

      my $vector = shift @things;
      if('HASH' ne ref $vector || $vector->{'a'} ne 'Vector') {
        $d -> reject("<:: expects a vector as the left most object");
      }
      else {
        $d -> resolve({
          a => 'Vector',
          value => [ @{$vector->{value}}, grep { defined $_ } @things ]
        });
      }
    }, sub {
      $d -> reject(@_);
    });
  }
  else {
    $self -> _reject($d, "missing expressions");
  }
}

sub doZip {
  my($self, $json, $d) = @_;

  # we want to zip together arbitrarily many streams
  # until we don't have any - undef for those that are empty
  if($json->{'expressions'}) {
    collect(
      map { $self -> execute($_) } @{$json->{'expressions'}}
    )->done(
      sub {
        my(@streams) = map { @$_ } @_;
        collect (
          map {
            my $head = deferred;
            if(defined $_) {
              $self -> _get_head($_, $head);
            }
            else {
              $head -> resolve(undef);
            }
            $head -> promise;
          } @streams
        )->done(sub {
          my(@heads) = map { @$_ } @_;
          if(!grep { defined $_ } @heads) {
            $d -> resolve(undef);
          }
          else {
            collect(
              map {
                my $tail = deferred;
                if(defined $_) {
                  $self -> _get_tail($_, $tail);
                }
                else {
                  $tail -> resolve(undef);
                }
                $tail->promise;
              } @streams
            )->done(sub {
              my(@tails) = map { @$_ } @_;
              $d -> resolve({
                a => 'List',
                head => {
                  a => 'Vector',
                  value => \@heads
                },
                tail_promise => {
                  a => 'LambdaWithClosure',
                  bindings => [],
                  bindings_with_defaults => [],
                  options => {},
                  closure => {
                    environment => {},
                    namespaces => {}
                  },
                  expression => {
                    a => 'Zip',
                    expressions => [
                      map {
                        +{
                          a => 'Identity',
                          value => $_
                        }
                      } @tails
                    ]
                  }
                }
              });
            }, sub {
              $d -> reject(@_);
            });
          }
        }, sub {
          $d -> resolve(@_);
        });
      },
      sub {
        $d -> reject(@_);
      }
    );
  }
  else {
    $self->_reject($d, "missing expressions");
  }
}

sub _run_apply {
  my($self, $d, $function, $bindings, $options) = (@_, {});
  my $cardinality = scalar(@$bindings);

  if('HASH' eq ref $function) {
    if($function->{'a'} eq 'Graph') {
      if($cardinality != 1) {
        $d -> reject("Expected one and only one argument when applying a graph. Found $cardinality.");
      }
      else {
        $self -> execute($bindings->[0])->done(sub {
          my($key) = @_;
          if(ref $key) {
            $d -> reject("Expected a scalar argument when applying a graph.");
          }
          else {
            $d -> resolve($function->{'@graph'}->{$key});
          }
        }, sub {
          $d->reject(@_);
        });
      }
    }
  }
}

sub doPropertyLit {
  my($self, $json, $d) = @_;

  if(defined $json->{'value'}) {
    my @bits = @{$json->{'value'}};
    if(@bits == 2) {
      my $href = $self->context->get_namespace($bits[0]);
      if(defined $href) {
        $d -> resolve({ a => 'Property', value => $href . $bits[1] });
      }
      else {
        $d -> reject("Namespace prefix $bits[0] is not defined");
      }
    }
    else {
      $d -> resolve({ a => 'Property', value => $bits[0]});
    }
  }
  else {
    $self -> _reject($d, 'missing value');
  }
}

sub doForwardWalk {
  my($self, $json, $d) = @_;
  $d -> resolve($json);
}

sub _walk_forward {
  my($self, $d, $graph, $step_expression, @steps) = @_;

  $self->execute($step_expression) -> done(
    sub {
      my($step) = @_;
      if($step -> {'a'} eq 'Property') {
        my @objects = map {
          my($n) = $_;
          if($n -> is_literal) {
            if($n->is_numeric_type) {
              Numeric($n -> numeric_value);
            }
            else {
              String($n->literal_value, $n->literal_value_language);
            }
          }
          elsif($n -> is_resource || $n -> is_blank) {
            {
              a => 'TripleStore',
              subject => $n,
              base => $graph->{base},
              graph => $graph->{graph}
            };
          }
          else {
            undef;
          }
        } $graph -> {'graph'}->objects(
          $graph->{'subject'},
          RDF::Trine::Node::Resource->new($step->{'value'})
        );
        if(@objects > 1) {
          $d -> resolve(\@objects);
        }
        else {
          $d -> resolve(@objects);
        }
      }
      else {
        $d -> reject('Unknown graph traversal step');
      }
    },
    sub {
      $d->reject(@_);
    }
  );
}

sub _walk_backward {
  my($self, $d, $graph, $step, @steps) = @_;
}

sub doPropWalk {
  my($self, $json, $d) = @_;

  # We want to look at the first thing and see if it's a node or a URI
  # If it's a URI, we resolve it into an RDF record we can use
  if($json->{'expressions'}) {
    my @expressions = @{$json->{'expressions'}};
    $self->execute(shift @expressions) -> done(
      sub {
        my($graph) = @_;
        if('HASH' eq ref $graph && $graph->{'a'} eq 'URI') {
          # resolve
          my $resolver = DHDataKernel::Engine::Resolver->instance;
          $self->cost($self->cost + 9); # cost 10 to resolve a URI
          $resolver -> get($graph->{'value'}) -> done(
            sub {
              my($real_graph) = @_;
              my $next_step = shift @expressions;
              if($next_step -> {'a'} eq 'ForwardWalk') {
                $self->_walk_forward($d, $real_graph, $next_step->{'expression'}, @expressions);
              }
              elsif($next_step -> {'a'} eq 'ReverseWalk') {
                $self->_walk_backward($d, $real_graph, $next_step->{'expression'}, @expressions);
              }
              else {
                $d->reject("Improper expression in graph traversal");
              }
            }, sub {
              $d->reject(@_);
            }
          );
        }
      },
      sub {
        $d->reject(@_);
      }
    )
  }
  else {
    $self -> _reject($d, 'missing expressions');
  }
}

sub doBuildURI {
  my($self, $json, $d) = @_;

  if($json->{'expression'}) {
    $self->execute($json->{'expression'})->done(sub {
      my($result) = @_;
      if(ref $result && $result->{'a'} eq 'URI') {
        $d -> resolve($result);
      }
      elsif(ref $result) {
        $d -> reject('A built URI must be a URI or a String');
      }
      else {
        $d -> resolve({
          a => 'URI',
          value => $result
        });
      }
    }, sub {
      $d -> reject(@_);
    });
  }
  else {
    $self -> _reject($d, 'missing expression');
  }
}

# If the last expression results in a lambda, then we're doing a composition
sub doMap {
  my($self, $json, $d) = @_;

  if($json -> {'expressions'}) {
    collect(
      map { $self -> execute($_) } @{$json->{'expressions'}}
    ) -> done(
      sub {
        my(@expressions) = map { @{$_} } @_;
        my $last = pop @expressions;
        if(grep { ('HASH' ne ref $_) || $_->{'a'} ne 'LambdaWithClosure' } @expressions) {
          $d -> reject("All but the last term in a sequence of '\@' must be a lambda");
        }
        elsif(grep { 1 != @{$_->{'bindings'}} } @expressions) {
          $d -> reject("All lambdas in a sequence of '\@' must have arity 1");
        }
        elsif('HASH' ne ref $last) {
          $d -> reject("The final expression in a map sequence isn't a valid value");
        }
        else {
          given($last->{'a'}) {
            when('LambdaWithClosure') {
              # we're all lambdas... so compose them!
              if(@{$last->{'bindings'}} != 1) {
                $d -> reject("All lambdas in a sequence of '\@' must have arity 1");
              }
              else {
                $d -> resolve($self->make_map($self->compose_lambdas(@expressions, $last)));
              }
            }
            when('Vector') {
              # we want to produce a new vector with the mapped values
              my $map = $self->compose_lambdas(@expressions);
              collect(
                map {
                  my $d2 = deferred;
                  $self->_run_apply($d2, $map, [ $_ ]);
                  $d2->promise;
                } @{$last->{'value'}}
              )->done(sub {
                $d -> resolve(Vector(
                  map { @$_ } @_
                ));
              }, sub {
                $d -> reject(@_);
              });
            }
            default {
              # build map and then apply it to $last
              my $map = $self -> make_map($self->compose_lambdas(@expressions));

              my $new_self = $self->new(
                context => $self->context->new(
                  environment => {
                    %{$map->{closure}->{environment}},
                    $map->{bindings}->[0] => $last
                  },
                  namespaces => {},
                ),
                cost => $self->cost,
                max_cost => $self->max_cost
              );
              $new_self -> execute($map->{'expression'}) -> done(sub {
                $self->cost($new_self->cost);
                $d -> resolve(@_);
              }, sub {
                $self->cost($new_self->cost);
                $d -> reject(@_);
              });
            }
          }
        }
      }, sub {
        $d -> reject(@_);
      }
    )
  }
  else {
    $self->_reject($d, 'missing expressions');
  }
}

# filter := (
#   filter_f(ff, f, s) :> {
#     (f(s')) : [ s', ff(ff, f, s...) ],
#     (     ) : ff(ff, f, s...)
#   };
#   filter_f(filter_f, _, _)
# );
# filter(f, _)
#
sub doFilter {
  my($self, $json, $d) = @_;

  if($json->{'expression'} && $json->{'stream'}) {
    my($filter, $stream) = @{$json}{'expression', 'stream'};
    if('HASH' ne ref $stream) {
      $d -> resolve(undef);
      return;
    }
    given($stream->{'a'}) {
      when('Vector') {
        collect(
          map {
            my $deferred = deferred;
            $self -> _run_apply($deferred, $filter, [ $_ ], {});
            $deferred -> promise;
          } @{$stream->{'value'}}
        )->done(sub {
          my(@flags) = map { @$_ } @_;
          my @new_vector;
          my @old_vector = @{$stream->{'value'}};
          my $idx = 0;
          while($idx < @old_vector) {
            if($flags[$idx]) {
              push @new_vector, $old_vector[$idx];
            }
            $idx++;
          }
          $d->resolve({
            a => 'Vector',
            value => \@new_vector
          });
        }, sub {
          $d->reject(@_);
        });
      }
      when('List') {
        # we need to run through the stream until we get a hit on head
        my $head_p = deferred;
        $self -> _get_head($stream, $head_p);
        $head_p->promise->done(sub {
          my($head) = @_;
          if(!defined $head) {
            $d->resolve({ a => 'List' });
            return;
          }
          my $tail_p = deferred;
          $self -> _get_tail($stream, $tail_p);
          $tail_p->promise->done(sub {
            my($tail) = @_;
            my $filter_p = deferred;
            $self -> _run_apply($filter_p, $filter, [ $head ], {});
            $filter_p->promise->done(sub {
              my($f) = @_;
              if('HASH' eq ref $f && $f -> {'value'}) {
                $d -> resolve({
                  a => 'List',
                  head => $head,
                  tail_promise => {
                    a => 'LambdaWithClosure',
                    closure => {
                      environment => {},
                      namespaces => {}
                    },
                    bindings => [],
                    bindings_with_defaults => [],
                    options => {},
                    expression => {
                      a => 'Filter',
                      expression => $filter,
                      stream => $tail
                    }
                  }
                });
              }
              else {
                $self -> doFilter(
                  {
                    a => 'Filter',
                    expression => $filter,
                    stream => $tail
                  },
                  $d
                );
              }
            }, sub {
              $d -> reject(@_);
            });
          }, sub {
            $d -> reject(@_);
          });
        }, sub {
          $d -> reject(@_);
        });
      }
      default {
        my $filter_p = deferred;
        $self -> _run_apply($filter_p, $filter, [ $stream ], {});
        $filter_p->promise->done(sub {
          my($f) = @_;
          if('HASH' eq ref $f && $f -> {'value'}) {
            $d -> resolve($stream);
          }
          else {
            $d -> resolve(undef);
          }
        }, sub {
          $d->reject(@_);
        });
      }
    }
  }
}

sub doInvert {
  my($self, $json, $d) = @_;

  if($json->{'expression'}) {
    $self->execute($json->{'expression'})->done(sub {
      my($result) = @_;
      if(ref $result eq 'HASH' && $result->{'a'} eq 'LambdaWithClosure') {
        my $new_result = {
          %{$result}
        };
        $new_result->{'expression'} = {
          a => 'Invert',
          expression => $new_result->{'expression'}
        };
        $d -> resolve($new_result);
      }
      elsif('HASH' eq ref $result) {
        given($result->{'a'}) {
          when('Boolean') { $d -> resolve(Boolean(!$result->{'value'})); }
          when('Numeric') { $d -> resolve(Boolean($result->{'value'}->is_zero)); }
          when('String') { $d -> resolve(Boolean($result->{'value'} eq '')); }
          when('Vector') { $d -> resolve(Boolean(@{$result->{'value'}} == 0)); }
          when('List') { $d -> resolve(Boolean(!defined($result->{'head'}) && !defined($result->{'tail'}) && !defined($result->{'tail_promise'}))); }
          when('TripleStore') { $d -> resolve(Boolean($result->{'graph'}->size == 0)); }
          default { $d -> resolve(TRUE); }
        }
      }
      else {
        $d -> resolve(Boolean(1));
      }
    }, sub {
      $d -> reject(@_);
    });
  }
  else {
    $self -> _reject($d, 'missing expression');
  }
}

sub compose_lambdas {
  my $self = shift;
  my @lambdas = reverse @_;

  my $new_engine = $self -> with_child_scope;

  my $expression = Dallycot::AST::Fetch->new('#');

  for my $idx (0..$#lambdas) {
    $new_engine -> context -> add_assignment("__lambda_".$idx, $lambdas[$idx]);
    $expression = Dallycot::AST::Apply->new(
      Dallycot::AST::Fetch->new('__lambda_'.$idx),
      [ $expression ]
    );
  }

  $new_engine -> Lambda($expression, [ '#' ]);
}

sub compose_filters {
  my $self = shift;
  my @filters = @_;

  if(@filters == 1) {
    return $filters[0];
  }

  my $new_engine = $self -> with_child_scope;

  my $expression = Dallycot::AST::Fetch->new('#');
  my $idx = 0;
  my @applications = map {
    $idx += 1;
    $new_engine -> context -> add_assignment("__lambda_".$idx, $_);
    Dallycot::AST::Apply->new(
      Dallycot::AST::Fetch->new('__lambda_'.$idx),
      [ $expression ]
    );
  } @filters;

  $new_engine -> Lambda(
    Dallycot::AST::All->new(@applications),
    [ '#' ]
  );
}

#
# map_f(f, t, s) :> (
#   (?s) : [ t(s'), f(f, t, s...) ]
#   (  ) : [ ]
# )
#
# ___transform := t
# map_t := { map_f(map_f, ___transorm, #) }
#
our $MAPPER = bless( [
  bless( [
    [
      bless( [
        bless( [ 's' ], 'Dallycot::AST::Fetch' )
      ], 'Dallycot::AST::Defined' ),
      bless( [
        bless( [
          bless( [ 't' ], 'Dallycot::AST::Fetch' ),
          [
            bless( [
              bless( [ 's' ], 'Dallycot::AST::Fetch' )
            ], 'Dallycot::AST::Head' )
          ],
          {}
        ], 'Dallycot::AST::Apply' ),
        bless( [
          bless( [ 'f' ], 'Dallycot::AST::Fetch' ),
          [
            bless( [ 'f' ], 'Dallycot::AST::Fetch' ),
            bless( [ 't' ], 'Dallycot::AST::Fetch' ),
            bless( [
              bless( [ 's' ], 'Dallycot::AST::Fetch' )
            ], 'Dallycot::AST::Tail' )
          ],
          {}
        ], 'Dallycot::AST::Apply' )
      ], 'Dallycot::AST::BuildList' )
    ],
    [
      undef,
      bless( [], 'Dallycot::AST::BuildList' )
    ]
  ], 'Dallycot::AST::Condition' ),
  [ 'f', 't', 's' ],
  [],
  {},
  {},
  {}
], 'Dallycot::Value::Lambda' );

our $MAP_APPLIER = #bless( [
  bless( [
    bless( [ '__map_f' ], 'Dallycot::AST::Fetch' ),
    [
      bless( [ '__map_f' ], 'Dallycot::AST::Fetch' ),
      bless( [ '___transform' ], 'Dallycot::AST::Fetch' ),
      bless( [ 's' ], 'Dallycot::AST::Fetch' )
    ],
    {}
  ], 'Dallycot::AST::Apply' ); #,
#   [ 's' ],
#   [],
#   {}
# ], 'Dallycot::AST::Lambda' );

sub make_map {
  my $self = shift;
  my $transform = shift;

  my $new_engine = $self -> with_child_scope;

  $new_engine -> context -> add_assignment("___transform", $transform);

  $new_engine -> context -> add_assignment("__map_f", $MAPPER);

  $new_engine -> Lambda($MAP_APPLIER, [ 's' ]);
}

# filter := (
#   filter_f(ff, f, s) :> (
#     (?s) : (
#       (f(s')) : [ s', ff(ff, f, s...) ],
#       (     ) :       ff(ff, f, s...)
#     )
#     (  ) : [ ]
#   );
#   filter_f(filter_f, _, _)
# );
# filter(f, _)
#
our $FILTER = bless( [
  bless( [
    [
      bless( [
        bless( [ 's' ], 'Dallycot::AST::Fetch' )
      ], 'Dallycot::AST::Defined' ),
      bless( [
        [
          bless( [
            bless( [ 'f' ], 'Dallycot::AST::Fetch' ),
            [
              bless( [
                bless( [ 's' ], 'Dallycot::AST::Fetch' )
              ], 'Dallycot::AST::Head' )
            ],
            {}
          ], 'Dallycot::AST::Apply' ),
          bless( [
            bless( [
              bless( [ 's' ], 'Dallycot::AST::Fetch' )
            ], 'Dallycot::AST::Head' ),
            bless( [
              bless( [ 'ff' ], 'Dallycot::AST::Fetch' ),
              [
                bless( [ 'ff' ], 'Dallycot::AST::Fetch' ),
                bless( [ 'f' ], 'Dallycot::AST::Fetch' ),
                bless( [
                  bless( [ 's' ], 'Dallycot::AST::Fetch' )
                ], 'Dallycot::AST::Tail' )
              ],
              {}
            ], 'Dallycot::AST::Apply' )
          ], 'Dallycot::AST::BuildList' )
        ],
        [
          undef,
          bless( [
            bless( [ 'ff' ], 'Dallycot::AST::Fetch' ),
            [
              bless( [ 'ff' ], 'Dallycot::AST::Fetch' ),
              bless( [ 'f' ], 'Dallycot::AST::Fetch' ),
              bless( [
                bless( [ 's' ], 'Dallycot::AST::Fetch' )
              ], 'Dallycot::AST::Tail' )
            ],
            {}
          ], 'Dallycot::AST::Apply' )
        ]
      ], 'Dallycot::AST::Condition' )
    ],
    [
      undef,
      bless( [], 'Dallycot::AST::BuildList' )
    ]
  ], 'Dallycot::AST::Condition' ),
  [ 'ff', 'f', 's' ],
  [],
  {},
  {},
  {}
], 'Dallycot::Value::Lambda' );

our $FILTER_APPLIER = bless( [
  bless( [ '__filter_f' ], 'Dallycot::AST::Fetch' ),
  [
    bless( [ '__filter_f' ], 'Dallycot::AST::Fetch' ),
    bless( [ '___filter' ], 'Dallycot::AST::Fetch' ),
    bless( [ 's' ], 'Dallycot::AST::Fetch' )
  ],
  {}
], 'Dallycot::AST::Apply' );

sub make_filter {
  my $self = shift;
  my $filter = shift;

  my $new_engine = $self -> with_child_scope;

  $new_engine -> context -> add_assignment("___filter", $filter);

  $new_engine -> context -> add_assignment("__filter_f", $FILTER);

  $new_engine -> Lambda($FILTER_APPLIER, [ 's' ]);
}

1;
