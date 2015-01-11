use lib 't/lib';

use strict;
use warnings;

use Test::More;

use LibraryHelper;

BEGIN { require_ok 'Dallycot::Library::Core::Streams' };

uses 'http://www.dallycot.net/ns/streams/1.0#';

isa_ok(Dallycot::Library::Core::Streams->instance, 'Dallycot::Library');

my $result;

$result = run('length("foo")');

is_deeply $result, Numeric(3), "The length of 'foo' is 3";

$result = run("length([1,2,3])");

is_deeply $result, Numeric(3), "[1,2,3] has three elements";

$result = run("length(range(1,3))");

is_deeply $result, Numeric('inf'), "1..3 has 'inf' elements";

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

$result = run("fibonacci-sequence[8]");

is_deeply $result, Numeric(21), "8th Fibonacci is 21";

$result = run("fibonacci(8)");

is_deeply $result, Numeric(21), "8th Fibonacci is 21";

$result = run("factorials[2]");

is_deeply $result, Numeric(2), "2! is 2";

$result = run("factorials[4]");

is_deeply $result, Numeric(24), "4! is 24";



$result = run("prime-pairs");

isa_ok $result, "Dallycot::Value::Stream";

$result = run("prime-pairs[1]");

is_deeply $result, Vector(Numeric(1), Numeric(2)), "First two primes are 1,2";

$result = run("prime-pairs[4]");

is_deeply $result, Vector(Numeric(5), Numeric(7)), "Fourth two primes are 5,7";

$result = run("twin-primes");

isa_ok $result, "Dallycot::Value::Stream";

$result = run("twin-primes[1]");

is_deeply $result, Vector(Numeric(3), Numeric(5)), "First twin primes are 3, 5";

# # 1 2 3 5 7 11 13 17 19 23 29 31
# #     .....  ...   ...      ...
# #      1 2    3     4        5

$result = run("twin-primes[5]");

is_deeply $result, Vector(Numeric(29), Numeric(31)), "Fifth pair is <29,31>";

done_testing();
