use lib 't/lib';

use strict;
use warnings;

use Test::More;

use LibraryHelper;

require Dallycot::Library::Core::Streams;

uses 'http://www.dallycot.net/ns/math/1.0#',
     'http://www.dallycot.net/ns/streams/1.0#';

BEGIN { require_ok 'Dallycot::Library::Core::Math' };

isa_ok(Dallycot::Library::Core::Math->instance, 'Dallycot::Library');

my $result;

$result = run('even?(3)');

is_deeply $result, Boolean(0), "3 is not even";

$result = run('even?(4)');

is_deeply $result, Boolean(1), "4 is even";

$result = run('odd?(3)');

is_deeply $result, Boolean(1), "3 is odd";

$result = run('odd?(4)');

is_deeply $result, Boolean(0), "4 is not odd";

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

$result = run("factorial(4)");

is_deeply $result, Numeric(24), "factorial(4) should be 24";

$result = run("random(123)");

isa_ok $result, 'Dallycot::Value::Numeric';

done_testing();
