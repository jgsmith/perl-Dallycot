use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

BEGIN { 
  use_ok 'Dallycot::Context';
  use_ok 'Dallycot::AST';
  use_ok 'Dallycot::Parser';
};

my $context = Dallycot::Context -> new;

my $child_context = $context -> new(
  parent => $context
);

##
# Namespace management
##

$context -> add_namespace(ex => 'http://example.com/ns');

is 'http://example.com/ns', $context -> get_namespace('ex'), "Retrieve previously set namespace";

is 'http://example.com/ns', $child_context -> get_namespace('ex'), "Retrieve namespace from parent context";

$child_context -> add_namespace(ex => 'http://example.com/ns2');

is 'http://example.com/ns', $context -> get_namespace('ex'), "Retrieve previously set namespace in parent context";

is 'http://example.com/ns2', $child_context -> get_namespace('ex'), "Retrieve namespace masking parent context";

eval {
  $child_context -> add_namespace(ex => 'http://example.com/ns3');
};

ok $@, "Setting a namespace twice in a child scope should throw an error";

is 'http://example.com/ns2', $child_context -> get_namespace('ex'), "Second assignment of namespace shouldn't change the value";


##
# Environment management
##

$context -> add_assignment(f => 'foo');

ok $context -> has_assignment('f'), "Check that assignment is made";
ok $child_context -> has_assignment('f'), "Check that assignment is made from child context pov";

is $context -> get_assignment('f'), 'foo', "Retrieve previously set assignment";
is $child_context -> get_assignment('f'), 'foo', "Retrieve previously set assignment from parent context";

ok !$context -> has_assignment('g'), "Check that a non-existant assignment doesn't exist";
ok !$child_context -> has_assignment('g'), "Check that a non-existant assignment doesn't exist from child's pov";

$child_context -> add_assignment(f => 'bar');

eval {
  $child_context -> add_assignment(f => 'baz');
};

ok $@, "Setting an assignment twice in a scope should throw an error";

is 'bar', $child_context -> get_assignment('f'), "Second assignment shouldn't change the value";

##
# Closure creation
##

my $node = bless [ 'f' ] => 'Dallycot::AST::Fetch';

is $node -> identifiers, 'f';

my $closure_context = $context -> make_closure($node);

ok $closure_context -> has_assignment('f');

is $closure_context->get_assignment('f'), $context->get_assignment('f');


# my $parser = Dallycot::Parser->new;

# $node = $parser->parse('[ n, self(self, n+1) ]');

# $closure_context = $context -> make_closure($node);

# ok !$closure_context -> has_assignment('self');
# ok !$closure_context -> has_assignment('n');
# ok !$closure_context -> has_assignment('upfrom_f');

done_testing();
