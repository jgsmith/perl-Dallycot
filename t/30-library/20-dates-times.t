use lib 't/lib';

use strict;
use warnings;

use Test::More;

use LibraryHelper;

BEGIN { require_ok 'Dallycot::Library::Core::DateTime' };

isa_ok(Dallycot::Library::Core::DateTime->instance, 'Dallycot::Library');

uses 'http://www.dallycot.net/ns/core/1.0#';
uses 'http://www.dallycot.net/ns/loc/1.0#';
uses 'http://www.dallycot.net/ns/date-time/1.0#';

ok(Dallycot::Registry->instance->has_namespace('http://www.dallycot.net/ns/date-time/1.0#'), 'DateTime namespace is registered');

my $result;

$result = run('duration(<1>)');

ok !DateTime::Duration->compare($result->value, Duration(years => 1)->value), "duration(<1>) is one year";

done_testing();
