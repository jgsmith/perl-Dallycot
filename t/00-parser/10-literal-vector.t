use lib 't/lib';

use Test::More;
use ParserHelper;

test_parses(
  '<1,2,3>' => [vector(intLit(1), intLit(2), intLit(3))],

  '<<this is four words>>' => [vectorLit(stringLit('this'), stringLit('is'), stringLit('four'), stringLit('words'))],

  '<<this\ is two\ words>>' => [vectorLit(stringLit('this is'), stringLit('two words'))],

);

done_testing();
