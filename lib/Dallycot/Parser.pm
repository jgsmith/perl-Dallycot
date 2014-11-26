package Dallycot::Parser;

use v5.20;
use strict;
use warnings;
use experimental qw(switch);

use Marpa::R2;
use Math::BigRat;

my $grammar = Marpa::R2::Scanless::G->new({
  action_object => __PACKAGE__,
  bless_package => 'Dallycot::AST',
  default_action => 'copy_arg0',
  source => do { local($/); my $s = <DATA>; \$s; }
});

our $PARSING_LIBRARY;

sub new {
  bless {} => __PACKAGE__;
}

sub parse {
  my($self, $input) = @_;

  local($PARSING_LIBRARY) = 0;

  $self -> _parse($input);
}

sub _parse {
  my($self, $input) = @_;

  my $re = Marpa::R2::Scanless::R->new({ grammar => $grammar });

  eval {
    $re -> read(\$input);
  };
  if($@) {
    print STDERR $@;
    return undef;
  }
  my $parse = $re->value;
  my $result;
  if($parse && $$parse && $$parse->isa('Dallycot::AST::Sequence')) {
    $result = [@{$$parse}];
  }
  elsif($parse) {
    $result = [$$parse];
  }
  else {
    $result = [bless [] => 'Dallycot::AST::Expr'];
  }

  return $result;
}

sub parse_library {
  my($self, $class, $input) = @_;

  local($PARSING_LIBRARY) = $class;

  $self -> _parse($input);
}

#--------------------------------------------------------------------

sub copy_arg0 {
  $_[1];
}

sub block {
  my(undef, @statements) = @_;

  if(@statements > 1) {
    bless [ @statements ] => 'Dallycot::AST::Sequence';
  }
  else {
    $statements[0];
  }
}

sub ns_def {
  my(undef, $ns, $href) = @_;

  bless [ $ns, $href ] => 'Dallycot::AST::XmlnsDef';
}

sub lambda {
  my(undef, $expression, $arity) = (@_, 1);
  bless [
    $expression,

      (
        $arity == 0
        ? []
        : $arity == 1
          ? [ '#' ]
          : [ map { '#'.$_ } 1..$arity ]
      ),
      []
    ,
    {}
  ] => 'Dallycot::AST::Lambda';
}

sub negate {
  my(undef, $expression) = @_;

  given($expression) {
    when('Dallycot::AST::Negation') {
      $expression->[0];
    }
    default {
      bless [ $expression ] => 'Dallycot::AST::Negation';
    }
  }
}

sub invert {
  my(undef, $expression) = @_;

  given($expression) {
    when('Dallycot::AST::Invert') {
      $expression->[0];
    }
    default {
      bless [ $expression ] => 'Dallycot::AST::Invert';
    }
  }
}

sub build_sum_product {

  my(undef, $Sum, $Negation, $left, $right) = @_;

  my $ret;

  my @expressions;

  # combine left/right as appropriate into a single sum
  given(ref $left) {
    when($Sum) {
      @expressions = @{$left};
      given(ref $right) {
        when($Sum) {
          push @expressions, @{$right};
        }
        default {
          push @expressions, $right;
        }
      }
    }
    default {
      given(ref $right) {
        when($Sum) {
          @expressions = ($left, @{$right});
        }
        default {
          @expressions = ($left, $right);
        }
      }
    }
  }

  # now go through an consolidate sums and differences
  my(@differences, @sums);

  foreach my $expr (@expressions) {
    given(ref $expr) {
      when($Sum) {
        foreach my $sub_expr (@{$expr}) {
          given(ref $sub_expr) {
            when($Negation) { # adding -(...)
              given(ref $sub_expr->[0]) {
                when($Sum) { # adding -(a+b+...)
                  push @differences, @{$sub_expr->[0]};
                }
                default {
                  push @sums, $sub_expr;
                }
              }
            }
            default {
              push @sums, $sub_expr;
            }
          }
        }
      }
      when($Negation) {
        given(ref $expr->[0]) {
          when($Sum) {
            foreach my $sub_expr (@{$expr->[0]}) {
              given(ref $sub_expr) {
                when($Negation) {
                  push @sums, $sub_expr->[0];
                }
                default {
                  push @differences, $sub_expr->[0];
                }
              }
            }
          }
          when($Negation) {
            push @sums, $expr->[0];
          }
          default {
            push @differences, $expr->[0];
          }
        }
      }
      default {
        push @sums, $expr;
      }
    }
  }

  given(scalar(@differences)) {
    when(0) { }
    when(1) {
      push @sums, bless [ $differences[0] ] => $Negation
    }
    default {
      push @sums,
        bless [
          bless [ @differences ] => $Sum
        ] => $Negation;
    }
  }

  bless [ @sums ] => $Sum;
}

sub product {
  my(undef, $left, $right) = @_;

  build_sum_product(undef, 'Dallycot::AST::Product', 'Dallycot::AST::Reciprocal', $left, $right);
}

sub divide {
  my(undef, $numerator, $dividend) = @_;

  product(undef, $numerator, (bless [ $dividend ] => 'Dallycot::AST::Reciprocal'));
}

sub modulus {
  my(undef, $expr, $mod) = @_;

  given($expr) {
    when('Dallycot::AST::Modulus') {
      push @{$expr}, $mod;
      $expr;
    }
    default {
      bless [ $expr, $mod ] => 'Dallycot::AST::Modulus';
    }
  }
}

sub sum {
  my(undef, $left, $right) = @_;

  build_sum_product(undef, 'Dallycot::AST::Sum', 'Dallycot::AST::Negation', $left, $right);
}

sub subtract {
  my(undef, $left, $right) = @_;

  sum(undef, $left, bless [ $right ] => 'Dallycot::AST::Negation');
}

my %ops = qw(
  <  Dallycot::AST::StrictlyIncreasing
  <= Dallycot::AST::Increasing
  =  Dallycot::AST::Equality
  <> Dallycot::AST::Unique
  >= Dallycot::AST::Decreasing
  >  Dallycot::AST::StrictlyDecreasing
);

sub inequality {
  my(undef, $left, $op, $right) = @_;

  if(ref $left eq $ops{$op} && ref $right eq ref $left) {
    push @{$left}, @{$right};
    $left;
  }
  elsif(ref $left eq $ops{$op}) {
    push @{$left}, $right;
    $left;
  }
  elsif(ref $right eq $ops{$op}) {
    unshift @{$right}, $left;
    $right;
  }
  else {
    bless [ $left, $right ] => $ops{$op};
  }
}

sub all {
  my(undef, $left, $right) = @_;

  if(ref $left eq 'Dallycot::AST::All') {
    push @{$left}, $right;
    $left;
  }
  else {
    bless [ $left, $right ] => 'Dallycot::AST::All';
  }
}

sub any {
  my(undef, $left, $right) = @_;

  if(ref $left eq 'Dallycot::AST::Any') {
    push @{$left}, $right;
    $left;
  }
  else {
    bless [ $left, $right ] => 'Dallycot::AST::Any';
  }
}

sub stream {
  my(undef, $expressions) = @_;

  bless $expressions => 'Dallycot::AST::BuildList';
}

sub empty_stream {
  bless [] => 'Dallycot::AST::BuildList';
}

sub compose {
  my(undef, @functions) = @_;

  bless [
    map {
      if(ref $_ eq 'Dallycot::AST::Compose') {
        @{$_}
      }
      else {
        $_
      }
    } @functions
  ] => 'Dallycot::AST::Compose';
}

sub compose_map {
  my(undef, @functions) = @_;

  bless [ @functions ] => 'Dallycot::AST::BuildMap';
}

sub compose_filter {
  my(undef, @functions) = @_;

  bless [ @functions ] => 'Dallycot::AST::BuildFilter';
}

sub build_string_vector {
  my(undef, $lit) = @_;

  my $lang = 'en';

  if($lit =~ s/\@([a-z][a-z](_[A-Z][A-Z])?)$//) {
    $lang = $1;
  }

  $lit =~ s/^<<//;
  $lit =~ s/>>$//;
  my @matches;

  while($lit =~ m{((?:[^\\\s]|\\.)+)\s*}g) {
    my $m = $1;
    $m =~ s[\\(.)] {
      my $char = $1;
      given($char) {
        when('n') { "\n" }
        when('t') { "\t" }
        default   { $char }
      }
    }egis;
    push @matches, $m;
  }

  bless [
    map {
      bless [ $_, $lang ] => 'Dallycot::Value::String';
    } @matches
  ] => 'Dallycot::Value::Vector';
}

sub integer_literal {
  my(undef, $lit) = @_;

  bless [ Math::BigRat -> new($lit) ] => 'Dallycot::Value::Numeric';
}

sub rational_literal {
  my(undef, $num, $den) = @_;

  bless [
    do {
      my $rat = Math::BigRat->new(
        Math::BigInt->new($num),
        Math::BigInt->new($den)
      );
      $rat->bnorm();
      $rat;
    }
  ] => 'Dallycot::Value::Numeric';
}

sub float_literal {
  my(undef, $lit) = @_;
  bless [ Math::BigRat->new($lit) ] => 'Dallycot::Value::Numeric';
}

sub string_literal {
  my(undef, $lit) = @_;

  my $lang = 'en';

  if($lit =~ s/\@([a-z][a-z](_[A-Z][A-Z])?)$//) {
    $lang = $1;
  }

  bless [ substr($lit,1,length($lit)-2), $lang ] => 'Dallycot::Value::String';
}

sub bool_literal {
  bless [ $_[0] eq 'true' ] => 'Dallycot::Value::Boolean';
}

sub uri_literal {
  my(undef, $lit) = @_;
  bless [ substr($lit,1,length($lit)-2) ] => 'Dallycot::Value::URI';
}

sub uri_expression {
  my(undef, $expression) = @_;

  bless [ $expression ] => 'Dallycot::AST::BuildURI';
}

sub combine_identifiers_options {
  my(undef, $bindings, $options) = (@_,[]);

  if('HASH' eq ref $bindings) {
    {
      bindings => $bindings->{'bindings'},
      bindings_with_defaults => $bindings->{'bindings_with_defaults'},
      options => {
        map { @$_ } @$options
      }
    }
  }
  else {
    {
      bindings => $bindings,
      bindings_with_defaults => [],
      options => {
        map { @$_ } @$options
      }
    };
  }
}

sub relay_options {
  my(undef, $options) = @_;
  {
    bindings => [],
    options => {
      map { @$_ } @$options
    }
  };
}

sub fetch {
  my(undef, $ident) = @_;

  bless [ $ident ] => 'Dallycot::AST::Fetch';
}

sub assign {
  my(undef, $ident, $expression) = @_;

  bless [ $ident, $expression ] => 'Dallycot::AST::Assign';
}

sub apply {
  my(undef, $function, $bindings) = (@_);

  if($PARSING_LIBRARY && $function->isa('Dallycot::AST::Fetch') && $function->[0] eq 'call' && $bindings->{'bindings'}->[0]->isa('Dallycot::Value::String')) {
    # we expect the first binding to be a Str
    bless [
      $PARSING_LIBRARY,
      (shift @{$bindings->{'bindings'}})->value,
      $bindings->{bindings},
      $bindings->{options}
    ] => 'Dallycot::AST::LibraryFunction';
  }
  else {
    bless [
      $function,
      $bindings->{bindings},
      $bindings->{options}
    ] => 'Dallycot::AST::Apply';
  }
}

sub apply_sans_params {
  my(undef, $function) = @_;

  bless [
    $function,
    [],
    {}
  ] => 'Dallycot::AST::Apply';
}

sub list {
  my(undef, @things) = @_;

  \@things;
}

sub head {
  my(undef, $expression) = @_;

  bless [ $expression ] => 'Dallycot::AST::Head';
}

sub tail {
  my(undef, $expression) = @_;

  bless [ $expression ] => 'Dallycot::AST::Tail';
}

sub cons {
  my(undef, $scalar, $stream) = @_;

  if(ref $stream eq 'Dallycot::AST::Cons') {
    push @{$stream}, $scalar;
    $stream;
  }
  else {
    bless [
      $stream,
      $scalar
    ] => 'Dallycot::AST::Cons';
  }
}

sub stream_vectors {
  my(undef, @vectors) = @_;

  bless [ @vectors ] => 'Dallycot::AST::ConsVectors';
}

sub function_definition_sans_args {
  my(undef, $identifier, $expression) = @_;

  function_definition(undef, $identifier, {
    bindings => [],
    bindings_with_defaults => []
  }, $expression);
}

sub function_definition {
  my(undef, $identifier, $args, $expression) = @_;

  if(ref $args) {
    bless [
      $identifier,
      bless [
        $expression,
          $args -> {bindings},
          $args -> {bindings_with_defaults}
        ,
        $args->{options}
      ] => 'Dallycot::AST::Lambda'
    ] => 'Dallycot::AST::Assign';
  }
  else {
    bless [
      $identifier,
      bless [
        $expression,
        [
          (
            $args == 0
              ? []
              : $args == 1
                ? [ '#' ]
                : [ map { '#'.$_ } 1..$args ]
          ),
          []
        ],
        {}
      ] => 'Dallycot::AST::Lambda'
    ] => 'Dallycot::AST::Assign';
  }
}

sub option {
  my(undef, $identifier, $default) = @_;

  [ $identifier, $default ];
}

sub combine_parameters {
  my(undef, $identifiers, $identifiers_with_defaults) = @_;

  {
    bindings => $identifiers,
    bindings_with_defaults => $identifiers_with_defaults
  };
}

sub parameters_only {
  my(undef, $bindings) = @_;

  {
    bindings => $bindings,
    bindings_with_defaults => []
  };
}

sub parameters_with_defaults_only {
  my(undef, $bindings) = @_;
  {
    bindings => [],
    bindings_with_defaults => $bindings
  };
}

sub placeholder {
  bless [] => 'Dallycot::AST::Placeholder';
}

sub condition_list {
  my(undef, $conditions, $otherwise) = @_;

  bless [
    @$conditions,
    (defined($otherwise) ? ( [ undef, $otherwise ] ) : ())
  ] => 'Dallycot::AST::Condition';
}

sub condition {
  my(undef, $guard, $expression) = @_;

  [ $guard, $expression ]
}

sub prop_request {
  my(undef, $node, $req) = @_;

  if(ref $node eq 'Dallycot::AST::PropWalk') {
    push @{$node}, $req;
    $node;
  }
  else {
    bless [ $node, $req ] => 'Dallycot::AST::PropWalk';
  }
}

sub forward_prop_request {
  my(undef, $expression) = @_;

  bless [ $expression ] => 'Dallycot::AST::ForwardWalk';
}

sub reverse_prop_request {
  my(undef, $expression) = @_;

  bless [ $expression ] => 'Dallycot::AST::ReverseWalk';
}

# implied object is the enclosing node definition
sub left_prop {
  my(undef, $prop, $subject) = @_;

  bless [ $subject, $prop, undef ] => 'Dallycot::AST::Property';
}

# implied subject is the enclosing node definition
sub right_prop {
  my(undef, $prop, $object) = @_;

  bless [ undef, $prop, $object ] => 'Dallycot::AST::Property';
}

sub build_node {
  my(undef, $expressions) = @_;

  bless [ @$expressions ] => 'Dallycot::AST::BuildNode';
}

sub prop_literal {
  my(undef, $lit) = @_;

  bless [ split(/:/, $lit) ] => 'Dallycot::AST::PropertyLit';
}

sub prop_alternatives {
  my(undef, $left, $right) = @_;

  if(ref $left eq 'Dallycot::AST::AnyProperty') {
    push @{$left}, $right;
    $left;
  }
  else {
    bless [ $left, $right ] => 'Dallycot::AST::AnyProperty';
  }
}

sub prop_closure {
  my(undef, $prop) = @_;

  bless [ $prop ] => 'Dallycot::AST::PropertyClosure';
}

sub build_vector {
  my(undef, $expressions) = @_;

  bless $expressions => 'Dallycot::AST::BuildVector';
}

sub empty_vector {
  bless [] => 'Dallycot::Value::Vector';
}

sub vector_constant {
  my(undef, $constants) = @_;

  bless $constants => 'Dallycot::Value::Vector';
}

sub stream_constant {
  my(undef, $constants) = @_;

  if(@$constants) {
    my $result = bless [ pop @$constants, undef ] => 'Dallycot::Value::List';
    while(@$constants) {
      $result = bless [ pop @$constants, $result ] => 'Dallycot::Value::List';
    }
    $result;
  }
  else {
    bless [] => 'Dallycot::Value::List';
  }
}

sub zip {
  my(undef, $left, $right) = @_;

  if(ref $left eq 'Dallycot::AST::Zip') {
    if($right eq 'Dallycot::AST::Zip') {
      push @{$left}, @{$right};
      $left;
    }
    else {
      push @{$left}, $right;
      $left;
    }
  }
  elsif(ref $right eq 'Dallycot::AST::Zip') {
    unshift @$right, $left;
    $right;
  }
  else {
    bless [ $left, $right ] => 'Dallycot::AST::Zip';
  }
}

sub vector_index {
  my(undef, $vector, $index) = @_;

  if(ref $vector eq 'Dallycot::AST::Index') {
    push @{$vector}, $index;
  }
  else {
    bless [ $vector, $index ] => 'Dallycot::AST::Index';
  }
}

sub vector_push {
  my(undef, $vector, $scalar) = @_;

  if($vector->[0] eq 'Push') {
    push @{$vector}, $scalar;
  }
  else {
    [ Push => ($vector, $scalar) ]
  }
}

sub defined_q {
  my(undef, $expression) = @_;

  bless [ $expression ] => 'Dallycot::AST::Defined';
}

##
# Eventually, Range will be a type representing all values between
# two endpoints.
#
# Q: how to indicate open/closed endpoints
#
# ( e1 .. e2 )
# [ e1 .. e2 )
# ( e1 .. e2 ]
# [ e1 .. e2 ]
#
sub semi_range {
  my(undef, $expression) = @_;

  bless [ $expression, undef ] => 'Dallycot::AST::BuildRange';
}

sub closed_range {
  my(undef, $left, $right) = @_;

  bless [ $left, $right ] => 'Dallycot::AST::BuildRange';
}

sub stream_reduction {
  my(undef, $start, $function, $stream) = @_;

  bless [ $start, $function, $stream ] => 'Dallycot::AST::Reduce';
}

sub promote_value {
  my(undef, $expression, $type) = @_;

  if(ref $expression eq 'Dallycot::AST::TypePromotion') {
    push @{$expression}, $type;
    $expression;
  }
  else {
    bless [ $expression, $type ] => 'Dallycot::AST::TypePromotion';
  }
}

1;

__DATA__

:start ::= Block

Block ::= Statement+ separator => STMT_SEP action => block

Statement ::= Expression
            | NSDef action => ns_def
            | FuncDef

Expression ::= ConditionList
             | Scalar
             | Vector
             | Stream
             | Function
             | Node
             | Assign
             | TypePromotion

TypePromotion ::= Expression ('^^') TypeSpec action => promote_value

TypeSpec ::= TypeName
           | TypeSpec PIPE TypeName

TypeName ::= Name
           | QCName


ExpressionList ::= Expression+ separator => COMMA action => list

Bindings ::= Binding* separator => COMMA action => list

Binding ::= Expression
          | (UNDERSCORE) action => placeholder

ConstantValue ::=
      Integer action => integer_literal
    | Integer (DIV) Integer action => rational_literal
    | Float action => float_literal
    | String action => string_literal
    | Boolean action => bool_literal
    | (COLON) Identifier action => prop_literal
    | (COLON) QCName action => prop_literal
    | ConstantStream action => stream_constant
    | ConstantVector action => vector_constant

ConstantStream ::= (LB) ConstantValues (RB)
                 | (LB) (RB)

ConstantVector ::= (LT) ConstantValues (GT)
                 | (LT) (GT)

ConstantValues ::= ConstantValue+ separator => COMMA action => list

Scalar ::=
      Integer action => integer_literal
    | Float action => float_literal
    | String action => string_literal
    | Boolean action => bool_literal
    | Identifier action => fetch
    | LambdaArg action => fetch
    | Stream QUOTE action => head
    | Node PropRequest action => prop_request
    | Apply
    | Vector (LB_LB) Scalar (RB_RB) action => vector_index
    | Scalar (LB_LB) Scalar (RB_RB) action => vector_index
    | (MINUS) Scalar action => negate
    | ('?') Scalar action => defined_q
   || (LP) Block (RP) assoc => group
   || Expression ('<<') Function ('<<') Stream action => stream_reduction
   || Scalar (STAR) Scalar action => product
    | Scalar (DIV) Scalar action => divide
   || Scalar (MOD) Scalar action => modulus
   || Scalar (PLUS) Scalar action => sum
    | Scalar (MINUS) Scalar action => subtract
   || Scalar Inequality Scalar action => inequality
   || Scalar (AND) Scalar action => all
   || Scalar (OR) Scalar action => any

Node ::=
      NodeDef
    | Identifier action => fetch
    | Uri action => uri_literal
    | ('<(') Expression (')>') action => uri_expression
    | Node PropRequest action => prop_request
    | Apply

Stream ::=
      Identifier action => fetch
    | LambdaArg action => fetch
    | Apply
    | Stream PropRequest action => prop_request
    | (LB) ExpressionList (RB) assoc => group action => stream
    | (LB) (RB) action => empty_stream
   || (LP) Block (RP) assoc => group
    | Scalar (DOT_DOT) Scalar action => closed_range
    | Scalar (DOT_DOT) action => semi_range
   || Stream (DOT_DOT_DOT) action => tail
   || Stream (Z) Vector action => zip assoc => right
    | Stream (Z) Stream action => zip
    | Vector (Z) Vector action => zip assoc => right
   || Function (MAP) Stream action => compose_map assoc => right
    | Function (FILTER) Stream action => compose_filter assoc => right
   || Scalar (COLON_COLON_GT) Stream action => cons assoc => right

Vector ::=
      Identifier action => fetch
    | LambdaArg action => fetch
    | StringVector action => build_string_vector
    | Apply
    | (LT) ExpressionList (GT) action => build_vector
    | (LT) (GT) action => empty_vector
    | ('<>') action => empty_vector
   || Function (MAP) Vector action => compose_map assoc => right
   || Function (FILTER) Vector action => compose_filter assoc => right
   || Vector (DOT_DOT_DOT) action => tail
   || Scalar (COLON_COLON_GT) Vector action => cons assoc => right
   || Vector (LT_COLON_COLON) Scalar action => vector_push

# Set ::=
#       Identifier action => fetch
#     | LambdaArg action => fetch
#     | Apply
#     | (LP_LC) ExpressionList (RC_RP) action => build_set
#     | (LP_LC) (RC_RP) action => empty_set
#     | Set (PIPE) Set action => set_union
#     | Set (AMP) Set action => set_intersection
#    || Function (MAP) Set action => compose_map assoc => right
#    || Function (FILTER) Set action => compose_map assoc => right
#    || Scalar (COLON_COLON_GT) Set action => set_add assoc => right
#    || Set (LT_COLON_COLON) Scalar action => set_add


NodeDef ::= (LC) NodePropList (RC) action => build_node

NodePropList ::= NodeProp+ action => list

NodeProp ::= PropIdentifier (RIGHT_ARROW) Expression action => right_prop
           | PropIdentifier (LEFT_ARROW) Expression action => left_prop

PropRequest ::= (RIGHT_ARROW) PropPattern action => forward_prop_request
              | (LEFT_ARROW) PropPattern action => reverse_prop_request

PropPattern ::= PropIdentifier
              | (STAR) PropPattern action => prop_closure
              | PropPattern (PIPE) PropPattern action => prop_alternatives
              | (LP) PropPattern (RP) assoc => group

PropIdentifier ::= (COLON) Identifier action => prop_literal
                 | (COLON) QCName action => prop_literal
                 | Expression

Function ::=
      Lambda
    | Identifier action => fetch
    | LambdaArg action => fetch
    | QCName action => fetch
    | Apply
    | (MINUS) Function action => negate
    | (TILDE) Function action => invert
    | (LP) Block (RP) assoc => group
   || Function (DOT) Function action => compose

Lambda ::=
      (LC) Expression (RC) action => lambda
    | (LC) Expression (RC) (SLASH) NonNegativeInteger action => lambda

Apply ::= Function (LP) FunctionArguments (RP) action => apply

NSDef ::= NSName (COLON_EQUAL) String action => ns_def

ConditionList ::= (LP) Conditions (RP) action => condition_list
                | (LP) Conditions Otherwise (RP) action => condition_list

Conditions ::= Condition+ action => list

Condition ::= (LP) Expression (RP) (COLON) Expression action => condition

Otherwise ::= (LP) (RP) (COLON) Expression

Assign ::= Identifier (COLON_EQUAL) Expression action => assign

FuncDef ::= Identifier (LP) FunctionParameters (RP) (COLON_GT) Expression action => function_definition
          | Identifier (LP) (RP) (COLON_GT) Expression action => function_definition_sans_args
          | Identifier (SLASH) PositiveInteger (COLON_GT) Expression action => function_definition

FunctionParameters ::= IdentifiersWithPossibleDefaults action => combine_identifiers_options
          | OptionDefinitions action => relay_options
          | IdentifiersWithPossibleDefaults (COMMA) OptionDefinitions action => combine_identifiers_options

IdentifiersWithPossibleDefaults ::= Identifiers action => parameters_only
          | IdentifiersWithDefaults action => parameters_with_defaults_only
          | Identifiers (COMMA) IdentifiersWithDefaults action => combine_parameters

IdentifiersWithDefaults ::= IdentifierWithDefault+ separator => COMMA action => list

IdentifierWithDefault ::= Identifier (EQUAL) ConstantValue action => option

OptionDefinitions ::= OptionDefinition+ separator => COMMA action => list

OptionDefinition ::= Identifier (RIGHT_ARROW) ConstantValue action => option

FunctionArguments ::= Bindings action => combine_identifiers_options
          | Options action => relay_options
          | Bindings (COMMA) Options action => combine_identifiers_options

Options ::= Option+ separator => COMMA action => list

Option ::= Identifier (RIGHT_ARROW) Expression action => option

Boolean ~ boolean

Inequality ~ inequality

Identifier ~ identifier | identifier '?'

Identifiers ::= Identifier+ separator => COMMA action => list

NSName ~ 'xmlns:' identifier

Name ~ identifier

QCName ~ qcname

Integer ~ integer

Float ~ float

PositiveInteger ~ positiveInteger

NonNegativeInteger ~ zero | positiveInteger

String ~ qqstring

StringVector ~ stringVector

Uri ~ uri

LambdaArg ~ HASH | HASH positiveInteger

AND ~ 'and'
COLON ~ ':'
#COLON_COLON ~ '::'
COLON_COLON_GT ~ '::>'
#COLON_COLON_COLON ~ ':::'
COLON_EQUAL ~ ':='
COLON_GT ~ ':>'
COMMA ~ ','
DIV ~ 'div'
DOT ~ '.'
DOT_DOT ~ '..'
DOT_DOT_DOT ~ '...'
DQUOTE ~ '"'
EQUAL ~ '='
FILTER ~ '%'
HASH ~ '#'
GT ~ '>'
GT_GT ~ '>>'
LB ~ '['
LB_LB ~ '[['
LC ~ '{'
LEFT_ARROW ~ '<-'
LP ~ '('
LP_STAR ~ '(*'
LT ~ '<'
LT_COLON_COLON ~ '<::'
LT_LT ~ '<<'
MAP ~ '@'
MINUS ~ '-'
MOD ~ 'mod'
OR ~ 'or'
PIPE ~ '|'
PLUS ~ '+'
QUOTE ~ [']
# '
RB ~ ']'
RB_RB ~ ']]'
RC ~ '}'
RIGHT_ARROW ~ '->'
RP ~ ')'
SLASH ~ '/'
STAR ~ '*'
STAR_RP ~ '*)'
TILDE ~ '~'
UNDERSCORE ~ '_'
Z ~ 'Z'

STMT_SEP ~ ';'

<any char> ~ [\d\D]

boolean ~ 'true' | 'false'

digits ~ [\d] | digits [\d]

identifier ~ <identifier bit> | identifier '-' <identifier bit>

<identifier bit> ~ [\w]+

inequality ~ '<' | '<=' | '=' | '<>' | '>=' | '>'

integer ~ negativeInteger | zero | positiveInteger

negativeInteger ~ '-' positiveInteger

nonZeroDigit ~ '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'

positiveInteger ~ nonZeroDigit | nonZeroDigit digits | 'inf'

float ~ negativeFloat | zero '.' zero | positiveFloat

negativeFloat ~ '-' positiveFloat

<positiveFloat integer part> ~ nonZeroDigit | nonZeroDigit digits

<positiveFloat fractional part> ~ digits

<positiveFloat exponent> ~ [eE] [-+] digits

positiveFloatSansExponent ~ <positiveFloat integer part> '.' zero
                          | <positiveFloat integer part> '.' <positiveFloat fractional part>
                          | zero '.' <positiveFloat fractional part>

positiveFloat ~ positiveFloatSansExponent
              | positiveFloatSansExponent <positiveFloat exponent>

qcname ~ identifier ':' identifier

# TODO: add @"lang" to end of string
#
qqstring ~ <qqstring value> | <qqstring value> '@' <qqstring lang>

<qqstring value> ~ DQUOTE qqstringContent DQUOTE | DQUOTE DQUOTE

qqstringChar ~ [^\"] | '\' <any char>
#"

<qqstring lang> ~ [a-z][a-z] | [a-z][a-z] '_' [A-Z][A-Z]

qqstringContent ~ qqstringChar | qqstringContent qqstringChar

stringVector ~ <stringVector value> | <stringVector value> '@' <qqstring lang>

<stringVector value> ~ LT_LT stringVectorContent GT_GT | LT_LT GT_GT

stringVectorContent ~ stringVectorChar | stringVectorContent stringVectorChar

stringVectorChar ~ [^>] | '>' [^>] | '\' <any char>
#'

uri ~ '<' uriScheme '://' uriAuthority '/' uriPath '>'

uriScheme ~ [a-z] | uriScheme [-a-z0-9+.]

uriAuthority ~ uriHostname | uriHostname ':' positiveInteger

uriPath ~ <uriPath segment> | uriPath '/' <uriPath segment>

<uriPath segment> ~ [^/\s]+

uriHostname ~ <uriHostname bit> '.' <uriHostname bit> | uriHostname '.' <uriHostname bit>

<uriHostname bit> ~ [-a-z0-9]+

zero ~ '0'

:discard ~ whitespace
whitespace ~ [\s]+
# allow comments
:discard ~ <comment>
<comment> ~ LP_STAR <comment body> STAR_RP
<comment body> ~ <comment char>*
#<statement sep char> ~ [;\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}\n\r]
<comment char> ~ [^*)] | '*' [^)] | [^*] ')'
