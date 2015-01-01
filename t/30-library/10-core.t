use lib 't/lib';

use strict;
use warnings;

use Test::More;

use LibraryHelper;

uses 'http://www.dallycot.net/ns/misc/1.0#',
     'http://www.dallycot.net/ns/functions/1.0#',
     'http://www.dallycot.net/ns/math/1.0#',
     'http://www.dallycot.net/ns/linguistics/1.0#',
     'http://www.dallycot.net/ns/streams/1.0#',
     'http://www.dallycot.net/ns/strings/1.0#'
     ;

BEGIN { require_ok 'Dallycot::Library::Core' };

isa_ok(Dallycot::Library::Core->instance, 'Dallycot::Library');

my $result;

$result = run('length("foo")');

is_deeply $result, Numeric(3), "The length of 'foo' is 3";

$result = run("length([1,2,3])");

is_deeply $result, Numeric(3), "[1,2,3] has three elements";

$result = run("length(range(1,3))");

is_deeply $result, Numeric('inf'), "1..3 has 'inf' elements";

done_testing();
