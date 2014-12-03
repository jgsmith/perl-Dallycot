use lib 't/lib';

use Test::More;
use ParserHelper;

test_parses(
  "<http://example.com/foo>" => [uriLit('http://example.com/foo')],

  '<("http://example.com/" + "foo")>' => [buildUri(
    sum(
      stringLit('http://example.com/'),
      stringLit('foo')
    )
  )],
);

done_testing();
