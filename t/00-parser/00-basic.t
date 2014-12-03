use lib 't/lib';

use Test::More;

BEGIN { 
  use_ok 'Dallycot::Parser';
  use_ok 'Dallycot::AST';
  use_ok 'Dallycot::Value';
};

use ParserHelper;

test_parses(
  "" => [Noop()]
);

done_testing();
