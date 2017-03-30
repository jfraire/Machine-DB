use Test::More tests => 6;
use strict;
use warnings;

use_ok 'Machine::DB::Handler';

my $h = Machine::DB::Handler->new(
    'topic name'     => 'Testing handlers',
    'topic'          => ':this/is/:a/:test',
    'SQL'            => 'sql statement',
    'place holders'  => [1,2,3],
    'response'       => { 
        topic  => 'response/:goes/here',
        fields => [qw(hola crayola)],
    },
);

isa_ok $h, 'Machine::DB::Handler';
isa_ok $h->responder, 'Machine::DB::Responder';

can_ok $h, 'response_topic', 'response_message';

my $data = { goes => 'is', hola => 4, crayola => undef };
is $h->response_topic($data), 'response/is/here',
    'Response topic is correctly delegated';
is_deeply $h->response_message($data), { hola => 4, crayola => undef },
    'Response message is correctly delegated';

done_testing();
