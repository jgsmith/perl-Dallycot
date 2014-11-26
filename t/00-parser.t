use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

BEGIN { 
  use_ok 'Dallycot::Parser';
  use_ok 'Dallycot::AST';
  use_ok 'Dallycot::Value';
};

my %trees = (
  "" => [Noop()],

  "123" => [intLit(123)],

  "0" => [intLit(0)],

  "0.0" => [floatLit("0.0")],

  "1.23" => [floatLit("1.23")],

  "4 * 1.23" => [product(intLit(4), floatLit(1.23))],

  "1.23e+23" => [floatLit("1.23e+23")],

  'primes Z primes...' => [zip(fetch('primes'), tail(fetch('primes')))],

  '{ #[[2]] - #[[1]] = 2 } % primes Z primes...' => [
    filter_(
      lambda(
        ['#'], {},
        equality(
          sum(
            index_(
              fetch('#'),
              intLit(2)
            ),
            negation(
              index_(
                fetch('#'),
                intLit(1)
              )
            )
          ),
          intLit(2)
        )
      ),
      zip(
        fetch('primes'),
        tail(fetch('primes'))
      )
    )
  ],

  '"String"^^URL' => [type_promotion(stringLit("String"), "URL")],

  '"String"^^x:Foo' => [type_promotion(stringLit("String"), "x:Foo")],

  '"String"^^URL^^HTML' => [type_promotion(stringLit("String"), "URL", "HTML")],

  '"This is a string"' => [stringLit("This is a string")],

  '"This is a string in French"@fr' => [stringLit("This is a string in French", "fr")],

  '"This is a string in US english"@en_US' => [stringLit("This is a string in US english", "en_US")],

  'a := 3' => [assignment('a', intLit(3))],

  '{ # + 3 }'     => [lambda(['#'], {}, sum(fetch('#'), intLit(3)))],

  '{ #1 + #2 }/2' => [lambda(['#1', '#2'], {}, sum(fetch('#1'), fetch('#2')))],

  'f(x,y) :> x + y' => [assignment(f => lambda(['x', 'y'], {}, sum(fetch('x'), fetch('y'))))],

  'f(x, y, a -> 3, b -> "foo", c -> <1,2,3>) :> x + y' => [
    assignment(
      f => lambda(
        ['x','y'],
        {
          a => intLit(3),
          b => stringLit("foo"),
          c => vectorLit(intLit(1), intLit(2), intLit(3)),
        },
        sum(
          fetch('x'),
          fetch('y'),
        )
      )
    )
  ],

  '[1, 2, 3]' => [list(intLit(1), intLit(2), intLit(3))],

  '1 = 2'       => [equality(intLit(1), intLit(2))],

  '1 = 2 = 3'   => [equality(intLit(1), intLit(2), intLit(3))],

  '1 < 2'       => [strictly_increasing(intLit(1), intLit(2))],

  '1 < 2 < 3'   => [strictly_increasing(intLit(1), intLit(2), intLit(3))],

  '1 <= 2'      => [increasing(intLit(1), intLit(2))],

  'g -> "foo"' => [prop_walk(fetch('g'), walk_forward(stringLit('foo')))],

  'G <- "name"' => [prop_walk(fetch('G'), walk_reverse(stringLit('name')))],

  'G <- :name' => [prop_walk(fetch('G'), walk_reverse(propLit('name')))],

  'g -> *:name' => [prop_walk(fetch('g'), walk_forward(prop_closure(propLit('name'))))],

  'g -> :name|:place' => [prop_walk(fetch('g'), walk_forward(prop_alterantives(propLit('name'), propLit('place'))))],

  '{ f -> g }' => [build_node(right_property(fetch('f'), fetch('g')))],

  '{ g <- f }' => [build_node(left_property(fetch('g'), fetch('f')))],

  '{ f -> g } -> :name' => [
    prop_walk(
      build_node(right_property(fetch('f'), fetch('g'))),
      walk_forward(propLit('name'))
    )
  ],

  '<1,2,3>' => [vector(intLit(1), intLit(2), intLit(3))],

  '<1,2,3>[[2]]' => [index_(vector(intLit(1), intLit(2), intLit(3)), intLit(2))],

  '<<this is four words>>' => [vectorLit(stringLit('this'), stringLit('is'), stringLit('four'), stringLit('words'))],

  '<<this\ is two\ words>>' => [vectorLit(stringLit('this is'), stringLit('two words'))],

  'quintuple @ <1,2,3>' => [map_(fetch('quintuple'), vector(intLit(1), intLit(2), intLit(3)))],

  '1 <= 2 <= 3' => [increasing(intLit(1), intLit(2), intLit(3))],

  '1 > 2 > 3'   => [strictly_decreasing(intLit(1), intLit(2), intLit(3))],

  '1 >= 2 >= 3' => [decreasing(intLit(1), intLit(2), intLit(3))],

  '1 <> 2 <> 3' => [unique(intLit(1), intLit(2), intLit(3))],

  '1 * 2' => [product(intLit(1), intLit(2))],

  '1 * 2 div 3 * 4 div 5' => [product(intLit(1), intLit(2), intLit(4), reciprocal(product(intLit(3), intLit(5))))],

  '1 + 2 - 3 + 4 - 5' => [sum(intLit(1), intLit(2), intLit(4), negation(sum(intLit(3), intLit(5))))],

  "[1, 2, 3]'" => [head(list(intLit(1), intLit(2), intLit(3)))],

  "[1, 2, 3]...'" => [head(tail(list(intLit(1), intLit(2), intLit(3))))],

  "[1, 2, 3]......'" => [head(tail(tail(list(intLit(1), intLit(2), intLit(3)))))],

  "1.." => [range(intLit(1))],

  "foo()" => [apply( fetch('foo') )],

  'string-take("The bright red spot.", <4,9>)' => [
    apply(
      fetch('string-take'),
      stringLit("The bright red spot."),
      vector(intLit(4), intLit(9))
    )
  ],

  'string-take("The bright red spot.", <10>)' => [
    apply(
      fetch('string-take'),
      stringLit("The bright red spot."),
      vector(intLit(10))
    )
  ],

  "0 << { #1 + #2 }/2 << [1,2,3,4,5]" => [
    reduce(
      intLit(0),
      lambda(['#1', '#2'], {}, sum(fetch('#1'), fetch('#2'))),
      list(intLit(1),intLit(2),intLit(3),intLit(4),intLit(5))
    )
  ],

  "yf(a, b, opt -> 14, foo -> <1,2,3>)" => [
    apply_with_options(
      fetch('yf'),
      {
        opt => intLit(14),
        foo => vector(intLit(1), intLit(2), intLit(3))
      },
      fetch('a'),
      fetch('b')
    )
  ],

  "[ n, yf(yf, n+1)]" => [list(fetch('n'), apply(fetch('yf'), fetch('yf'), sum(fetch('n'), intLit(1))))],

  "f @ g" => [map_(fetch('f'), fetch('g'))],

  "f % g" => [filter_(fetch('f'), fetch('g'))],

  "f . g" => [compose_(fetch('f'), fetch('g'))],

  "f . g . h" => [compose_(fetch('f'), fetch('g'), fetch('h'))],

  "f @ g % s" => [ map_(fetch('f'), filter_(fetch('g'), fetch('s'))) ],

  "{ # }" => [lambda(['#'], {}, fetch('#'))],

  "{ # } @ g" => [map_(lambda(['#'], {}, fetch('#')), fetch('g'))],

  "1 = 1 and 3 > 2" => [all_(equality(intLit(1),intLit(1)), strictly_decreasing(intLit(3), intLit(2)))],

  "1 = 1 or 3 > 2" => [any_(equality(intLit(1),intLit(1)), strictly_decreasing(intLit(3), intLit(2)))],

  "<http://example.com/foo>" => [uriLit('http://example.com/foo')],

  '<("http://example.com/" + "foo")>' => [buildUri(
    sum(
      stringLit('http://example.com/'),
      stringLit('foo')
    )
  )],

  "<http://dbpedia.org/resource/Semantic_Web> -> :rdfs:label" => [
    prop_walk(
      uriLit('http://dbpedia.org/resource/Semantic_Web'),
      walk_forward(propLit('rdfs:label'))
    )
  ],

  "upfrom_f(yf, n) :> [ n, yf(yf, n+1)]" => [assignment(
    upfrom_f => lambda(
      [qw(yf n)],
      {},
      list(
        fetch('n'),
        apply(
          fetch('yf'),
          fetch('yf'),
          sum(
            fetch('n'),
            intLit(1)
          )
        )
      )
    )
  )],

  "upfrom := upfrom_f(upfrom_f, _)" => [assignment(
    upfrom => apply(
      fetch('upfrom_f'),
      fetch('upfrom_f'),
      placeholder()
    )
  )],

  "upfrom_f(yf, n) :> [ n, yf(yf, n+1)];
   upfrom := upfrom_f(upfrom_f, _)" => sequence(
    assignment(
      upfrom_f => lambda(
        [qw(yf n)],
        {},
        list(
          fetch('n'),
          apply(
            fetch('yf'),
            fetch('yf'),
            sum(
              fetch('n'),
              intLit(1)
            )
          )
        )
      )
    ),
    assignment(
      upfrom => apply(
        fetch('upfrom_f'),
        fetch('upfrom_f'),
        placeholder()
      )
    )
  ),

  "[]" => [list()],

  "1 ::> []" => [cons(list(), intLit(1))],

  "upfrom_f(self, n) :> [ n, self(self, n+1) ]" => [assignment(upfrom_f => lambda(['self', 'n'], {}, list(fetch('n'), apply(fetch('self'), fetch('self'), sum(fetch('n'), intLit(1))))))],

  "upfrom(1)..." => [ tail(apply(fetch("upfrom"), intLit(1))) ],

  "evenq(n) :> n mod 2 = 0" => [assignment(
    evenq => lambda(
      ['n'],
      {},
      equality(
        modulus(
          fetch('n'),
          intLit(2)
        ),
        intLit(0)
      )
    )
  )],
  
  "?s" => [Defined(fetch('s'))],

  "(
    (?s) : 1 + ff(ff, s...)
    (  ) : 0
  )" => [conditions(
    condition(
      Defined(
        fetch('s')
      ),
      sum(
        intLit(1),
        apply(
          fetch('ff'),
          fetch('ff'),
          tail(
            fetch('s')
          )
        )
      )
    ),
    otherwise( 
      intLit(0)
    )
  )],

  "(
    (evenq(s')) : [ s', evens_f(f, s...) ]
    (         ) : evens_f(f, s...)
  )" => [conditions(
    condition(
      apply(
        fetch('evenq'),
        head(fetch('s'))
      ),
      list(
        head(fetch('s')),
        apply(
          fetch('evens_f'),
          fetch('f'),
          tail(fetch('s'))
        )
      )
    ),
    otherwise(
      apply(
        fetch('evens_f'),
        fetch('f'),
        tail(fetch('s'))
      )
    )
  )],

  "evens_f(f, s) :> (
    (evenq(s')) : [ s', f(f, s...) ]
    (         ) :       f(f, s...)
  )" => [assignment(
    evens_f => lambda(
      [qw(f s)],
      {},
      conditions(
        condition(
          apply(
            fetch('evenq'),
            head(fetch('s'))
          ),
          list(
            head(fetch('s')),
            apply(
              fetch('f'),
              fetch('f'),
              tail(fetch('s'))
            )
          )
        ),
        otherwise(
          apply(
            fetch('f'),
            fetch('f'),
            tail(fetch('s'))
          )
        )
      )
    )
  )],

  "odds := (
    odds_f(f, s) :> (
      (oddq(s')) : [ s', f(f, s...) ]
      (        ) :       f(f, s...)
    );
    odds_f(odds_f, _)
  )" => [assignment(
    odds => sequence(
      assignment(
        odds_f => lambda(
          [qw(f s)],
          {},
          conditions(
            condition(
              apply(
                fetch('oddq'),
                head(fetch('s'))
              ),
              list(
                head(fetch('s')),
                apply(
                  fetch('f'),
                  fetch('f'),
                  tail(fetch('s'))
                )
              )
            ),
            otherwise(
              apply(
                fetch('f'),
                fetch('f'),
                tail(fetch('s'))
              )
            )
          )
        )
      ),
      apply(
        fetch('odds_f'),
        fetch('odds_f'),
        placeholder()
      )
    )
  )],

  "map( { # * 5 }, upfrom(1))'" => [
    head(
      apply(
        fetch('map'),
        lambda(
          ['#'],
          {},
          product(
            fetch('#'),
            intLit(5)
          )
        ),
        apply(
          fetch('upfrom'),
          intLit(1)
        )
      )
    )
  ],

  " ({ # * 5 } @ upfrom(1))'" => [
    head(
      map_(
        lambda(
          ['#'],
          {},
          product(
            fetch('#'),
            intLit(5)
          )
        ),
        apply(
          fetch('upfrom'),
          intLit(1)
        )
      )
    )
  ]
);

my $parser = Dallycot::Parser->new;
$Data::Dumper::Indent = 1;
foreach my $expr (sort { length($a) <=> length($b) } keys %trees ) {

  my $parse = $parser->parse($expr);
  is_deeply($parse, $trees{$expr}, "Parsing ($expr)") or do {
    print STDERR "($expr): ", Data::Dumper->Dump([$parse]);
    # if('ARRAY' eq ref $parse) {
    #   print STDERR "\n   " . join("; ", map { $_ -> to_string } @$parse). "\n";
    # }
    # elsif($parse) {
    #   print STDERR "\n   " . $parse->to_string . "\n";
    # }
    print STDERR "expected: ", Data::Dumper->Dump([$trees{$expr}]);
  };
}

#my $s = "sum(s) :> 0 << { #1 + #2 }/2 << s";

#print $s, " ", Data::Dumper->Dump([$parser->parse($s)]);

done_testing();


#==============================================================================

sub Noop {
  bless [] => 'Dallycot::AST::Expr';
}

sub sequence {
  bless \@_ => 'Dallycot::AST::Sequence';
}

sub placeholder {
  bless [] => 'Dallycot::AST::Placeholder';
}

sub intLit {
  bless [ Math::BigRat->new(shift) ] => 'Dallycot::Value::Numeric';
}

sub floatLit {
  bless [ Math::BigRat->new(shift) ] => 'Dallycot::Value::Numeric';
}

sub stringLit {
  my($val, $lang) = (@_,'en');
  bless [ $val, $lang ] => 'Dallycot::Value::String';
}

sub fetch {
  bless [ shift ] => 'Dallycot::AST::Fetch';
}

sub list {
  bless \@_ => 'Dallycot::AST::BuildList';
}

sub cons {
  bless \@_ => 'Dallycot::AST::Cons';
}

sub sum {
  bless \@_ => 'Dallycot::AST::Sum';
}

sub negation {
  bless [ shift ] => 'Dallycot::AST::Negation';
}

sub modulus {
  bless \@_ => 'Dallycot::AST::Modulus';
}

sub product {
  bless \@_ => 'Dallycot::AST::Product';
}

sub reciprocal {
  bless [ shift ] => 'Dallycot::AST::Reciprocal';
}

sub equality {
  bless \@_ => 'Dallycot::AST::Equality';
}

sub increasing {
  bless \@_ => 'Dallycot::AST::Increasing';
}

sub decreasing {
  bless \@_ => 'Dallycot::AST::Decreasing';
}

sub strictly_increasing {
  bless \@_ => 'Dallycot::AST::StrictleIncreasing';
}

sub strictly_decreasing {
  bless \@_ => 'Dallycot::AST::StrictlyDecreasing';
}

sub unique {
  bless \@_ => 'Dallycot::AST::Unique';
}

sub assignment {
  my($identifier, $expression) = @_;
  bless [ $identifier, $expression ] => 'Dallycot::AST::Assign';
}

sub lambda {
  my($bindings, $options, $expression) = @_;
  
  bless [ $expression, $bindings, [], $options ] => 'Dallycot::AST::Lambda';
}

sub apply {
  bless [ shift, \@_, {} ] => 'Dallycot::AST::Apply';
}

sub apply_with_options {
  my($expression, $options, @bindings) = @_;

  bless [ $expression, \@bindings, $options ] => 'Dallycot::AST::Apply';
}

sub head {
  bless [ shift ] => 'Dallycot::AST::Head'
}

sub tail {
  bless [ shift ] => 'Dallycot::AST::Tail'
}

sub conditions {
  bless \@_ => 'Dallycot::AST::Condition'
}

sub condition {
  [ @_ ]
}

sub otherwise {
  [ undef, $_[0] ]
}

sub map_ {
  bless \@_ => 'Dallycot::AST::Map'
}

sub filter_ {
  bless \@_ => 'Dallycot::AST::BuildFilter'
}

sub compose_ {
  bless \@_ => 'Dallycot::AST::Compose'
}

sub any_ {
  bless \@_ => 'Dallycot::AST::Any'
}

sub all_ {
  bless \@_ => 'Dallycot::AST::All'
}

sub walk_forward {
  bless [ shift ] => 'Dallycot::AST::ForwardWalk'
}

sub walk_reverse {
  bless [ shift ] => 'Dallycot::AST::ReverseWalk'
}

sub prop_walk {
  bless \@_ => 'Dallycot::AST::PropWalk'
}

sub propLit {
  bless [ split(/:/, shift) ] => 'Dallycot::AST::PropertyLit'
}

sub prop_closure {
  bless [ shift ] => 'Dallycot::AST::PropertyClosure'
}

sub prop_alterantives {
  bless \@_ => 'Dallycot::AST::AnyProperty'
}

sub build_node {
  bless \@_ => 'Dallycot::AST::BuildNode'
}

sub right_property {
  bless [ undef, $_[0], $_[1] ] => 'Dallycot::AST::Property'
}

sub left_property {
  bless [ $_[1], $_[0], undef ] => 'Dallycot::AST::Property'
}

sub uriLit {
  bless [ shift ] => 'Dallycot::Value::URI'
}

sub buildUri {
  bless \@_ => 'Dallycot::AST::BuildUri'
}

sub vectorLit {
  bless \@_ => 'Dallycot::Value::Vector'
}

sub vector {
  bless \@_ => 'Dallycot::AST::BuildVector'
}

sub index_ {
  bless \@_ => 'Dallycot::AST::Index'
}

sub reduce {
  bless \@_ => 'Dallycot::AST::Reduce'
}

sub type_promotion {
  bless \@_ => 'Dallycot::AST::TypePromotion'
}

sub zip {
  bless \@_ => 'Dallycot::AST::Zip'
}

sub range {
  
  bless [ $_[0], $_[1] ] => 'Dallycot::AST::BuildRange'
}

sub Defined {
  bless [ $_[0] ] => 'Dallycot::AST::Defined'
}
