use lib 't/lib';

use strict;
use warnings;

use Test::More;

use LibraryHelper;

BEGIN { require_ok 'Dallycot::Library::Core::Functions' };

uses 'https://www.dallycot.net/ns/functions/1.0#';

isa_ok(Dallycot::Library::Core::Functions->instance, 'Dallycot::Library');

my $result;

done_testing();
