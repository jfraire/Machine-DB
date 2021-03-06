use Test::More tests => 4;
use strict;
use warnings;

use_ok 'Machine::DB::Responder';

my $r = Machine::DB::Responder->new(
    topic  => 'this/is/:a/:test',
    fields => [qw(hola crayola)],
);

is $r->topic_template, 'this/is/:a/:test',
    'Topic template is read correctly';

my $data = {
    a       => 1,
    test    => 2,
    hola    => 3,
    crayola => 4
};

is $r->response_topic($data), 'this/is/1/2',
    'Response topic is built correctly';

my $msg = $r->response_message($data);
is_deeply $msg, { hola => 3, crayola => 4 },
    'Response message is built correctly';

done_testing();
