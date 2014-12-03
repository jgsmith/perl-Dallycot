use lib 't/lib';

use Test::More;
use ParserHelper;

test_parses(
  'g -> "foo"' => [prop_walk(fetch('g'), walk_forward(stringLit('foo')))],

  'G <- "name"' => [prop_walk(fetch('G'), walk_reverse(stringLit('name')))],

  'G <- :name' => [prop_walk(fetch('G'), walk_reverse(propLit('name')))],

  'g -> *:name' => [prop_walk(fetch('g'), walk_forward(prop_closure(propLit('name'))))],

  'g -> :name|:place' => [prop_walk(fetch('g'), walk_forward(prop_alternatives(propLit('name'), propLit('place'))))],

  '{ f -> g } -> :name' => [
    prop_walk(
      build_node(right_property(fetch('f'), fetch('g'))),
      walk_forward(propLit('name'))
    )
  ],

  "<http://dbpedia.org/resource/Semantic_Web> -> :rdfs:label" => [
    prop_walk(
      uriLit('http://dbpedia.org/resource/Semantic_Web'),
      walk_forward(propLit('rdfs:label'))
    )
  ],
);

done_testing();
