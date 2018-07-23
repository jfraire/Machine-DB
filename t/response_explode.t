use Test::More tests => 4;
use JSON;
use strict;
use warnings;

use_ok 'Machine::DB::Responder';

my $r = Machine::DB::Responder->new(
    topic   => 'this/is/:a/:test',
    fields  => [qw(hola crayola)],
    explode => [qw(cracker)],
);

my %hash = (
    blue   => 'azul',
    orange => 'naranja',
    red    => 'rojo',
);

my $data = {
    a       => 1,
    test    => 2,
    hola    => 3,
    crayola => 4,
    cracker => encode_json(\%hash),
};

is $r->topic_template, 'this/is/:a/:test',
    'Topic template is read correctly';

my ($topic, $body) = $r->build_response($data);

is $topic, 'this/is/1/2',
    'Response topic is built correctly';

is_deeply $body, {
    hola    => 3,
    crayola => 4,
    blue    => 'azul',
    orange  => 'naranja',
    red     => 'rojo' },
    'Response message is built correctly';

done_testing();
