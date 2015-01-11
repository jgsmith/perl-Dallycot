use lib 't/lib';

use strict;
use warnings;

use Test::More;

use LibraryHelper;

BEGIN { require_ok 'Dallycot::Library::Core::Functions' };

uses 'http://www.dallycot.net/ns/functions/1.0#';

isa_ok(Dallycot::Library::Core::Functions->instance, 'Dallycot::Library');

my $result;

$result = run('Y((self) :> 3)');

isa_ok $result, 'Dallycot::Value::Lambda';

is $result->arity, 0, "Y((self) :> ...) takes no arguments";

done_testing();
