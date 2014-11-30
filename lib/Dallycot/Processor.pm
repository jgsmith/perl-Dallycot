package Dallycot::Processor;

# ABSTRACT: Run compiled Dallycot code.

use strict;
use warnings;

use utf8;
use Moose;

use Promises qw(deferred);

use experimental qw(switch);

use Dallycot::Context;
use Dallycot::Registry;
use Dallycot::Resolver;
use Dallycot::Value;
use Dallycot::AST;

use Readonly;

use Math::BigRat try => 'GMP';

has context => (
  is      => 'ro',
  isa     => 'Dallycot::Context',
  handles => [
    qw[
      has_assignment
      get_assignment
      add_assignment
      has_namespace
      get_namespace
      ]
  ],
  default => sub {
    Dallycot::Context->new;
  }
);

has max_cost => (
  is      => 'rw',
  isa     => 'Int',
  default => 100_000
);

has cost => (
  is      => 'rw',
  isa     => 'Int',
  default => 0
);

has parent => (
  is        => 'ro',
  predicate => 'has_parent',
  isa       => __PACKAGE__
);

sub add_cost {
  my ( $self, $delta ) = @_;

  if ( $self->has_parent ) {
    return $self->parent->add_cost($delta);
  }
  else {
    $self->cost( $self->cost + $delta );
    return $self->cost > $self->max_cost;
  }
}

sub with_child_scope {
  my ($self) = @_;

  return $self->new(
    parent  => $self,
    context => $self->context->new(
      parent => $self->context
    )
  );
}

sub with_new_closure {
  my ( $self, $environment, $namespaces ) = @_;

  return $self->new(
    parent  => $self,
    context => $self->context->new(
      environment => $environment,
      namespaces  => $namespaces
    )
  );
}

sub _execute_expr {
  my ( $self, $expr ) = @_;

  if ( 'ARRAY' eq ref $expr ) {
    return $self->execute(@$expr);
  }
  else {
    return $self->execute($expr);
  }
}

sub collect {
  my ( $self, @exprs ) = @_;

  return Promises::collect( map { $self->_execute_expr($_) } @exprs )->then(
    sub {
      map { @$_ } @_;
    }
  );
}

# for now, just returns the original values
sub coerce {
  my ( $self, $a, $b, $atype, $btype ) = @_;

  my $d = deferred;

  $d->resolve( $a, $b );

  return $d->promise;
}

sub make_lambda {
  my ( $self, $expression, $bindings, $bindings_with_defaults, $options ) = @_;

  $bindings               ||= [];
  $bindings_with_defaults ||= [];
  $options                ||= {};

  return Dallycot::Value::Lambda->new(
    expression             => $expression,
    bindings               => $bindings,
    bindings_with_defaults => $bindings_with_defaults,
    options                => $options,
    engine                 => $self
  );
}

sub make_boolean {
  my ( $self, $f ) = @_;
  return Dallycot::Value::Boolean->new($f);
}

sub make_numeric {
  my ( $self, $n ) = @_;
  return Dallycot::Value::Numeric->new($n);
}

sub make_string {
  my ( $self, $value, $lang ) = @_;
  return Dallycot::Value::String->new( $value, $lang );
}

sub make_vector {
  my ( $self, @things ) = @_;
  return Dallycot::Value::Vector->new(@things);
}

Readonly my $TRUE  => make_boolean( undef, 1 );
Readonly my $FALSE => make_boolean( undef, '' );
Readonly my $UNDEFINED => Dallycot::Value::Undefined->new;
Readonly my $ZERO      => make_numeric( undef, Math::BigRat->bzero() );
Readonly my $ONE       => make_numeric( undef, Math::BigRat->bone() );

sub TRUE ()      { return $TRUE }
sub FALSE ()     { return $FALSE }
sub UNDEFINED () { return $UNDEFINED }
sub ZERO ()      { return $ZERO }
sub ONE ()       { return $ONE }

sub execute_all {
  my ( $self, $deferred, @stmts ) = @_;

  $self->_execute_loop( $deferred, ['Any'], @stmts );
  return;
}

sub _execute_loop {
  my ( $self, $deferred, $expected_types, $stmt, @stmts ) = @_;

  if ( !@stmts ) {
    $self->_execute( $expected_types, $stmt )
      ->done( sub { $deferred->resolve(@_); }, sub { $deferred->reject(@_); } );
    return;
  }
  $self->_execute( ['Any'], $stmt )
    ->done( sub { $self->_execute_loop( $deferred, $expected_types, @stmts ) },
    sub { $deferred->reject(@_); } );
  return;
}

sub _execute {
  my ( $self, $expected_types, $ast ) = @_;

  my $d      = deferred;
  my $worked = eval {
    if ( $self->add_cost(1) ) {
      $d->reject("Exceeded maximum evaluation cost");
    }
    else {
      $ast->execute($self)->done(
        sub {
          $d->resolve(@_);
        },
        sub {
          $d->reject(@_);
        }
      );
    }
    1;
  };
  if ($@) {
    $d->reject($@);
  }
  elsif ( !$worked ) {
    $d->reject("Unable to evaluate");
  }
  return $d->promise;
}

sub execute {
  my ( $self, $ast, @ast ) = @_;

  my @expected_types = ('Any');

  if (@ast) {
    my $potential_types = pop @ast;

    if ( 'ARRAY' eq ref $potential_types ) {
      @expected_types = @$potential_types;
    }
    else {
      push @ast, $potential_types;
    }
  }

  my $d = deferred;

  if (@ast) {
    $self->_execute_loop( $d, \@expected_types, $ast, @ast );
  }
  else {
    $self->_execute( \@expected_types, $ast )
      ->done( sub { $d->resolve(@_); }, sub { $d->reject(@_); } );
  }
  return $d->promise;
}

# sub _run_apply {
#   my($self, $d, $function, $bindings, $options) = @_;
#   $options //= {};
#   my $cardinality = scalar(@$bindings);
#
#   if('HASH' eq ref $function) {
#     if($function->{'a'} eq 'Graph') {
#       if($cardinality != 1) {
#         $d -> reject("Expected one and only one argument when applying a graph. Found $cardinality.");
#       }
#       else {
#         $self -> execute($bindings->[0])->done(sub {
#           my($key) = @_;
#           if(ref $key) {
#             $d -> reject("Expected a scalar argument when applying a graph.");
#           }
#           else {
#             $d -> resolve($function->{'@graph'}->{$key});
#           }
#         }, sub {
#           $d->reject(@_);
#         });
#       }
#     }
#   }
#
#   return;
# }

sub compose_lambdas {
  my ( $self, @lambdas ) = @_;
  @lambdas = reverse @lambdas;

  my $new_engine = $self->with_child_scope;

  my $expression = Dallycot::AST::Fetch->new('#');

  for my $idx ( 0 .. $#lambdas ) {
    $new_engine->context->add_assignment( "__lambda_" . $idx, $lambdas[$idx] );
    $expression =
      Dallycot::AST::Apply->new(
      Dallycot::AST::Fetch->new( '__lambda_' . $idx ),
      [$expression] );
  }

  return $new_engine->make_lambda( $expression, ['#'] );
}

sub _add_filter_to_context {
  my ( $engine, $idx, $filter, $expression ) = @_;

  $engine->context->add_assignment( "__lambda_" . $idx, $filter );
  return Dallycot::AST::Apply->new(
    Dallycot::AST::Fetch->new( '__lambda_' . $idx ),
    [$expression] );
}

sub compose_filters {
  my ( $self, @filters ) = @_;

  if ( @filters == 1 ) {
    return $filters[0];
  }

  my $new_engine = $self->with_child_scope;

  my $expression = Dallycot::AST::Fetch->new('#');
  my $idx        = 0;
  my @applications =
    map { _add_filter_to_context( $new_engine, $idx++, $_, $expression ) }
    @filters;

  #   $idx += 1;
  #   $new_engine -> context -> add_assignment("__lambda_".$idx, $_);
  #   Dallycot::AST::Apply->new(
  #     Dallycot::AST::Fetch->new('__lambda_'.$idx),
  #     [ $expression ]
  #   );
  # } @filters;

  return $new_engine->make_lambda( Dallycot::AST::All->new(@applications),
    ['#'] );
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
my $MAPPER = bless(
  [
    bless(
      [
        [
          bless(
            [ bless( ['s'], 'Dallycot::AST::Fetch' ) ],
            'Dallycot::AST::Defined'
          ),
          bless(
            [
              bless(
                [
                  bless( ['t'], 'Dallycot::AST::Fetch' ),
                  [
                    bless(
                      [ bless( ['s'], 'Dallycot::AST::Fetch' ) ],
                      'Dallycot::AST::Head'
                    )
                  ],
                  {}
                ],
                'Dallycot::AST::Apply'
              ),
              bless(
                [
                  bless( ['f'], 'Dallycot::AST::Fetch' ),
                  [
                    bless( ['f'], 'Dallycot::AST::Fetch' ),
                    bless( ['t'], 'Dallycot::AST::Fetch' ),
                    bless(
                      [ bless( ['s'], 'Dallycot::AST::Fetch' ) ],
                      'Dallycot::AST::Tail'
                    )
                  ],
                  {}
                ],
                'Dallycot::AST::Apply'
              )
            ],
            'Dallycot::AST::BuildList'
          )
        ],
        [ undef, bless( [], 'Dallycot::AST::BuildList' ) ]
      ],
      'Dallycot::AST::Condition'
    ),
    [ 'f', 't', 's' ],
    [],
    {},
    {},
    {}
  ],
  'Dallycot::Value::Lambda'
);

my $MAP_APPLIER = bless(
  [
    bless( ['__map_f'], 'Dallycot::AST::Fetch' ),
    [
      bless( ['__map_f'],      'Dallycot::AST::Fetch' ),
      bless( ['___transform'], 'Dallycot::AST::Fetch' ),
      bless( ['s'],            'Dallycot::AST::Fetch' )
    ],
    {}
  ],
  'Dallycot::AST::Apply'
);

sub make_map {
  my ( $self, $transform ) = @_;

  my $new_engine = $self->with_child_scope;

  $new_engine->context->add_assignment( "___transform", $transform );

  $new_engine->context->add_assignment( "__map_f", $MAPPER );

  return $new_engine->make_lambda( $MAP_APPLIER, ['s'] );
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
my $FILTER = bless(
  [
    bless(
      [
        [
          bless(
            [ bless( ['s'], 'Dallycot::AST::Fetch' ) ],
            'Dallycot::AST::Defined'
          ),
          bless(
            [
              [
                bless(
                  [
                    bless( ['f'], 'Dallycot::AST::Fetch' ),
                    [
                      bless(
                        [ bless( ['s'], 'Dallycot::AST::Fetch' ) ],
                        'Dallycot::AST::Head'
                      )
                    ],
                    {}
                  ],
                  'Dallycot::AST::Apply'
                ),
                bless(
                  [
                    bless(
                      [ bless( ['s'], 'Dallycot::AST::Fetch' ) ],
                      'Dallycot::AST::Head'
                    ),
                    bless(
                      [
                        bless( ['ff'], 'Dallycot::AST::Fetch' ),
                        [
                          bless( ['ff'], 'Dallycot::AST::Fetch' ),
                          bless( ['f'],  'Dallycot::AST::Fetch' ),
                          bless(
                            [ bless( ['s'], 'Dallycot::AST::Fetch' ) ],
                            'Dallycot::AST::Tail'
                          )
                        ],
                        {}
                      ],
                      'Dallycot::AST::Apply'
                    )
                  ],
                  'Dallycot::AST::BuildList'
                )
              ],
              [
                undef,
                bless(
                  [
                    bless( ['ff'], 'Dallycot::AST::Fetch' ),
                    [
                      bless( ['ff'], 'Dallycot::AST::Fetch' ),
                      bless( ['f'],  'Dallycot::AST::Fetch' ),
                      bless(
                        [ bless( ['s'], 'Dallycot::AST::Fetch' ) ],
                        'Dallycot::AST::Tail'
                      )
                    ],
                    {}
                  ],
                  'Dallycot::AST::Apply'
                )
              ]
            ],
            'Dallycot::AST::Condition'
          )
        ],
        [ undef, bless( [], 'Dallycot::AST::BuildList' ) ]
      ],
      'Dallycot::AST::Condition'
    ),
    [ 'ff', 'f', 's' ],
    [],
    {},
    {},
    {}
  ],
  'Dallycot::Value::Lambda'
);

my $FILTER_APPLIER = bless(
  [
    bless( ['__filter_f'], 'Dallycot::AST::Fetch' ),
    [
      bless( ['__filter_f'], 'Dallycot::AST::Fetch' ),
      bless( ['___filter'],  'Dallycot::AST::Fetch' ),
      bless( ['s'],          'Dallycot::AST::Fetch' )
    ],
    {}
  ],
  'Dallycot::AST::Apply'
);

sub make_filter {
  my ( $self, $filter ) = @_;

  my $new_engine = $self->with_child_scope;

  $new_engine->context->add_assignment( "___filter", $filter );

  $new_engine->context->add_assignment( "__filter_f", $FILTER );

  return $new_engine->make_lambda( $FILTER_APPLIER, ['s'] );
}

1;
