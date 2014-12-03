use lib 't/lib';

use Test::More;

use ParserHelper;

test_parses(
  'a := 3' => [assignment('a', intLit(3))],

  "?s" => [Defined(fetch('s'))],
);

done_testing();

