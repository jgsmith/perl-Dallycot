use lib 't/lib';

use Test::More;
use ParserHelper;

test_parses(
  'primes Z primes...' => [zip(fetch('primes'), tail(fetch('primes')))],

  "[1, 2, 3]'" => [head(list(intLit(1), intLit(2), intLit(3)))],

  "[1, 2, 3]...'" => [head(tail(list(intLit(1), intLit(2), intLit(3))))],

  "[1, 2, 3]......'" => [head(tail(tail(list(intLit(1), intLit(2), intLit(3)))))],

  "upfrom(1)..." => [ tail(apply(fetch("upfrom"), intLit(1))) ],

  "0 << { #1 + #2 }/2 << [1,2,3,4,5]" => [
    reduce(
      intLit(0),
      lambda(['#1', '#2'], {}, sum(fetch('#1'), fetch('#2'))),
      list(intLit(1),intLit(2),intLit(3),intLit(4),intLit(5))
    )
  ],

  "1 ::> []" => [cons(list(), intLit(1))],

);

done_testing();
