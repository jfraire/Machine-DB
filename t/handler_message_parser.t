use Test::More tests => 3;
use JSON;
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

ok ref($h->msg_parser) eq 'CODE',
    'The message parser is a code reference';

my %msg = ( 
    topic => 'mqtt/is/simple/bus',
    messg => { hola => 1, crayola => 2 },
);

$msg{messg} = encode_json $msg{messg};
# note explain \%msg;

my $result = $h->parse_msg($msg{topic}, $msg{messg});
# note explain $result;

is_deeply $result, {
    hola => 1,
    crayola => 2,
    this    => 'mqtt',
    a       => 'simple',
    test    => 'bus'
}, 'Message was parsed correctly';

done_testing();
