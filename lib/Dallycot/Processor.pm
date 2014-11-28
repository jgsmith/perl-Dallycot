use strict;
use warnings;
package Dallycot::Processor;

# ABSTRACT: Run compiled Dallycot code.

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

sub make_lambda {
  my($self, $expression, $bindings, $bindings_with_defaults, $options) = @_;

  $bindings ||= [];
  $bindings_with_defaults ||= [];
  $options ||= {};

  Dallycot::Value::Lambda->new(
    $expression, $bindings, $bindings_with_defaults, $options,
    $self
  );
}

sub make_boolean {
  Dallycot::Value::Boolean->new($_[1]);
}

sub make_numeric {
  Dallycot::Value::Numeric->new($_[1]);
}

sub make_string {
  shift;
  Dallycot::Value::String->new(@_);
}

sub make_vector {
  shift;
  Dallycot::Value::Vector->new(@_);
}

use constant TRUE => make_boolean(undef,1);
use constant FALSE => make_boolean(undef,'');
use constant UNDEFINED => Dallycot::Value::Undefined->new;

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
  eval {
    if($self -> add_cost(1)) {
      $d -> reject("Exceeded maximum evaluation cost");
    }
    else {
      $ast -> execute($self, $d);
    }
  };
  if($@) {
    $d -> reject(@_);
  }
  $d -> promise;
}

sub execute {
  my($self, $ast, @ast) = @_;

  my @expected_types = ('Any');

  if(@ast) {
    my $potential_types = pop @ast;

    if('ARRAY' eq ref $potential_types) {
      @expected_types = @$potential_types;
    }
    else {
      push @ast, $potential_types;
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

  $new_engine -> make_lambda($expression, [ '#' ]);
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

  $new_engine -> make_lambda(
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

our $MAP_APPLIER = bless( [
    bless( [ '__map_f' ], 'Dallycot::AST::Fetch' ),
    [
      bless( [ '__map_f' ], 'Dallycot::AST::Fetch' ),
      bless( [ '___transform' ], 'Dallycot::AST::Fetch' ),
      bless( [ 's' ], 'Dallycot::AST::Fetch' )
    ],
    {}
  ], 'Dallycot::AST::Apply' );

sub make_map {
  my $self = shift;
  my $transform = shift;

  my $new_engine = $self -> with_child_scope;

  $new_engine -> context -> add_assignment("___transform", $transform);

  $new_engine -> context -> add_assignment("__map_f", $MAPPER);

  $new_engine -> make_lambda($MAP_APPLIER, [ 's' ]);
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

  $new_engine -> make_lambda($FILTER_APPLIER, [ 's' ]);
}

1;
