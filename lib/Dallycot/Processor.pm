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
      add_namespace
      get_namespace_search_path
      append_namespace_search_path
      ]
  ],
  default => sub {
    Dallycot::Context->new;
  }
);

has channels => (
  is => 'ro',
  isa => 'HashRef',
  default => sub { +{} },
  predicate => 'has_channels',
  lazy => 1
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

sub channel_send {
  my ( $self, $channel, @items ) = @_;

  if($self -> has_channels && exists($self -> channels->{$channel})) {
    if($self -> channels->{$channel}) {
      $self -> channels->{$channel}->send(@items);
    }
  }
  elsif($self -> has_parent) {
    $self -> parent -> channel_send($channel, @items);
  }
  return;
}

sub channel_read {
  my ( $self, $channel, %options ) = @_;

  if($self -> has_channels && exists($self -> channels -> {$channel})) {
    if($self -> channels -> {$channel}) {
      return $self -> channels -> {$channel} -> receive(%options);
    }
  }
  elsif($self -> has_parent) {
    return $self -> parent -> channel_read($channel, %options);
  }
  my $d = deferred;
  $d -> resolve(Dallycot::Value::String->new(''));
  return $d -> promise;
}

sub create_channel {
  my ( $self, $channel, $object ) = @_;

  $self -> channels->{$channel} = $object;
  return;
}

sub add_cost {
  my ( $self, $delta ) = @_;

  $self->cost( $self->cost + $delta );
  return $self->cost > $self->max_cost;
}

sub with_child_scope {
  my ($self) = @_;

  my $ctx = $self -> context;

  return __PACKAGE__->new(
    parent  => $self,
    max_cost => $self -> max_cost - $self -> cost,
    context => Dallycot::Context->new(
      parent => $ctx,
      namespace_search_path => $ctx->namespace_search_path
    )
  );
}

sub with_new_closure {
  my ( $self, $environment, $namespaces, $search_path ) = @_;

  return $self->new(
    parent  => $self,
    max_cost => $self -> max_cost - $self -> cost,
    context => Dallycot::Context->new(
      environment => $environment,
      namespaces  => $namespaces,
      namespace_search_path => ($search_path // $self->context->namespace_search_path)
    )
  );
}

sub DEMOLISH {
  my($self) = @_;

  $self -> parent -> add_cost($self -> cost) if $self -> has_parent;
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

Readonly my $TRUE  => Dallycot::Value::Boolean->new(1);
Readonly my $FALSE => Dallycot::Value::Boolean->new();
Readonly my $UNDEFINED => Dallycot::Value::Undefined->new;
Readonly my $ZERO      => Dallycot::Value::Numeric->new( Math::BigRat->bzero() );
Readonly my $ONE       => Dallycot::Value::Numeric->new( Math::BigRat->bone() );

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

  my $promise = eval {
    if ( $self->add_cost(1) ) {
      my $d = deferred;
      $d->reject("Exceeded maximum evaluation cost");
      $d -> promise;
    }
    else {
      $ast->execute($self);
    }
  };

  return $promise if $promise;

  my $d = deferred;
  if ($@) {
    $d->reject($@);
  }
  else {
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


  if (@ast) {
    my $d = deferred;
    $self->_execute_loop( $d, \@expected_types, $ast, @ast );
    return $d->promise;
  }
  else {
    return $self->_execute( \@expected_types, $ast );
  }
}

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
