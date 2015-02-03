use lib 't/lib';

use strict;
use warnings;

use Test::More;

use LibraryHelper;

BEGIN { require_ok 'Dallycot::Library::Core' };

isa_ok(Dallycot::Library::Core->instance, 'Dallycot::Library');

uses 'http://www.dallycot.net/ns/core/1.0#';

ok(Dallycot::Registry->instance->has_namespace('http://www.dallycot.net/ns/core/1.0#'), 'Core namespace is registered');

my $result;

$result = run('Y((self) :> 3)');

isa_ok $result, 'Dallycot::Value::Lambda';

is $result->arity, 0, "Y((self) :> ...) takes no arguments";

done_testing();
