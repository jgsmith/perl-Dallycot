use lib 't/lib';

use strict;
use warnings;

use Test::More;
use AnyEvent;
use Promises backend => ['AnyEvent'];

BEGIN { use_ok 'Dallycot::Library::Core' };

my $cv = AnyEvent -> condvar;

#Dallycot::Library::Core->initialize;

isa_ok(Dallycot::Library::Core->instance, 'Dallycot::Library');

sub Numeric {
  Dallycot::Value::Numeric -> new($_[0]);
}

sub Boolean {
  Dallycot::Value::Boolean -> new($_[0]);
}

sub String {
  Dallycot::Value::String->new(@_);
}

sub Vector {
  Dallycot::Value::Vector->new(@_);
}

my $processor = Dallycot::Processor -> new(
  context => Dallycot::Context -> new(
    namespace_search_path => [
      'https://www.dallycot.io/ns/misc/1.0#',
      'https://www.dallycot.io/ns/functions/1.0#',
      'https://www.dallycot.io/ns/math/1.0#',
      'https://www.dallycot.io/ns/linguistics/1.0#',
      'https://www.dallycot.io/ns/streams/1.0#',
      'https://www.dallycot.io/ns/strings/1.0#'
    ]
  )
);

my $parser = Dallycot::Parser->new;

my $result;

$result = run('odds');

$result = run('length("foo")');

is_deeply $result, Numeric(3), "The length of 'foo' is 3";

$result = run('even?(3)');

is_deeply $result, Boolean(0), "3 is not even";

$result = run('even?(4)');

is_deeply $result, Boolean(1), "4 is even";

$result = run('odd?(3)');

is_deeply $result, Boolean(1), "3 is odd";

$result = run('odd?(4)');

is_deeply $result, Boolean(0), "4 is not odd";

$result = run("upfrom(1)...'");

is_deeply $result, Numeric(2), "Second number starting at 1 is 2";

$result = run("odds...'");

is_deeply $result, Numeric(3), "Second odd is 3";

$result = run("odds...'");

is_deeply $result, Numeric(3), "Second odd is 3 with semi-range";

$result = run("range(3,7)...'");

is_deeply $result, Numeric(4), "Second in [3,7] is 4";

$result = run("(3..7)...'");

is_deeply $result, Numeric(4), "Second in 3..7 is 4";

$result = run("range(1,3).........'");

isa_ok $result, 'Dallycot::Value::Undefined', "Running off the end should result in undef";

$result = run("length([1,2,3])");

is_deeply $result, Numeric(3), "[1,2,3] has three elements";

$result = run("length(range(1,3))");

is_deeply $result, Numeric('inf'), "1..3 has 'inf' elements";

$result = run("primes'");

is_deeply $result, Numeric(1), "1 is the first prime";

$result = run("primes...'");

is_deeply $result, Numeric(2), "2 is the second prime";

$result = run("primes......'");

is_deeply $result, Numeric(3), "3 is the third prime";

$result = run("primes.........");

isa_ok $result, 'Dallycot::Value::Stream';

$result = run("primes.........'");

is_deeply $result, Numeric(5), "5 is the 4th prime";

$result = run("primes............");

isa_ok $result, 'Dallycot::Value::Stream';


$result = run("primes............'");

is_deeply $result, Numeric(7), "7 is the 5th prime";

$result = run("primes... ... ... ... ... ... ...'");

is_deeply $result, Numeric(17), "17 is the 8th prime";

$result = run("fibonacci-sequence... ... ... ... ...'");

is_deeply $result, Numeric(8), "6th Fibonacci is 8";

$result = run("fibonacci-sequence[[8]]");

is_deeply $result, Numeric(21), "8th Fibonacci is 21";

$result = run("fibonacci(8)");

is_deeply $result, Numeric(21), "8th Fibonacci is 21";

$result = run("factorials[[2]]");

is_deeply $result, Numeric(2), "2! is 2";

$result = run("factorial(4)");

is_deeply $result, Numeric(24), "factorial(4) should be 24";

$result = run("factorials[[4]]");

is_deeply $result, Numeric(24), "4! is 24";

$result = run("last(count-and-sum(1..9))");

is_deeply $result, Vector(Numeric(9), Numeric(45)), "count-and-sum of 1..9 is <9,45>";

$result = run("last(sum(1..9))");

is_deeply $result, Numeric(45), "Sum of 1..9 is 45";

$result = run("mean(1..9)");

isa_ok $result, 'Dallycot::Value::Stream';

$result = run("last(mean(1..9))");

is_deeply $result, Numeric(5), "Average of 1..9 is 5";

$result = run("last(min([1,-2,3,-4,5,-6,7]))");

is_deeply $result, Numeric(-6), "Minimum of [1,-2,3,-4,5,-6,7] is -6";

$result = run("last(max([1,-2,3,-4,5,-6,7]))");

is_deeply $result, Numeric(7), "Maximum of [1,-2,3,-4,5,-6,7] is 7";

$result = run("differences(1..)...'");

is_deeply $result, Numeric(-1), "Difference between successive numbers is -1";

$result = run("gcd(0, 123)");

is_deeply $result, Numeric(123), "gcd(0, 123) is 123";

$result = run("gcd(234, 0)");

is_deeply $result, Numeric(234), "gcd(234, 0) is 234";

$result = run("gcd(1599, 650)");

is_deeply $result, Numeric(13), "gcd(1599, 650) is 13";

$result = run("prime-pairs");

isa_ok $result, "Dallycot::Value::Stream";

$result = run("prime-pairs[[1]]");

is_deeply $result, Vector(Numeric(1), Numeric(2)), "First two primes are 1,2";

$result = run("prime-pairs[[4]]");

is_deeply $result, Vector(Numeric(5), Numeric(7)), "Fourth two primes are 5,7";

$result = run("twin-primes");

isa_ok $result, "Dallycot::Value::Stream";

$result = run("twin-primes[[1]]");

is_deeply $result, Vector(Numeric(3), Numeric(5)), "First twin primes are 3, 5";

# # 1 2 3 5 7 11 13 17 19 23 29 31
# #     .....  ...   ...      ...
# #      1 2    3     4        5

$result = run("twin-primes[[5]]");

is_deeply $result, Vector(Numeric(29), Numeric(31)), "Fifth pair is <29,31>";

#for my $idx (1..100) {
#  $result = run("twin-primes[[$idx]]");
#
#  print STDERR $idx, ": ", ($result->[0]->value||'-'), " ", ($result->[1]->value||'-'), "\n";
#}

$result = run('string-take("The bright red spot.", 5)');

is_deeply $result, String("The b"), "The first five characters of 'The bright...' are 'The b'";

$result = run('string-take("The bright red spot.", <4,9>)');

is_deeply $result, String(" brigh");

$result = run('string-take("The bright red spot.", <10>)');

is_deeply $result, String("t");

$result = run('string-drop("The bright red spot.", 10)');

is_deeply $result, String(" red spot.");

$result = run(q{stop-words("en")'});

is_deeply $result, String('a'), "'a' is the first stop word in English";

$result = run('language-classifier-languages');

isa_ok $result, 'Dallycot::Value::Vector', "language-classifier-languages is a vector";

$result = run('classifier := language-classifier(<<en es fr de>>)');

is_deeply [ @$result ], [qw(eng spa fra deu)], "Constructed a classifier";

#$result = run('language-classify(classifier, "The quick brown fox jumped over the lazy bear.")');

#is_deeply $result, String('en'), "Should return 'en' for English text";

#$result = run('language-classify(classifier, <http://en.wikipedia.org/wiki/Project_Gutenberg>)');

#is_deeply $result, String('en');

#$result = run('language-classify(classifier, <http://es.wikipedia.org/wiki/Proyecto_Gutenberg>)');

#is_deeply $result, String('es');

done_testing();

#==============================================================================

use Data::Dumper;
BEGIN { $Data::Dumper::Indent = 1; }

sub run {
  my($stmt) = @_;
  # print STDERR "Running ($stmt)\n";
  my $cv = AnyEvent -> condvar;

  eval {
    my $parse = $parser -> parse($stmt);
    if('HASH' eq $parse) {
      $parse = [ $parse ];
    }
    $processor -> max_cost(100000);
    $processor -> cost(0);
    $processor -> execute(@{$parse}) -> done(
      sub { $cv -> send( @_ ) },
      sub { $cv -> croak( @_ ) }
    );
  };

  if($@) {
    $cv -> croak($@);
  }

  my $ret = eval {
    $cv -> recv;
  };
  if($@) {
    warn "$stmt: $@";
  }
  #print STDERR "Cost of running ($stmt): ", $processor -> cost, "\n";
  $ret;
}
