use Test::More tests => 12;
use JSON;
use strict;
use warnings;

use_ok 'Machine::DB::Handler';

{
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

    my ($topic, $body) = $h->build_response($data);
    is $topic, 'response/is/here',
        'Response topic is correctly built';
    is_deeply $body, { hola => 4, crayola => undef },
        'Response message body is correctly built';
}

{
    my $h = Machine::DB::Handler->new(
        'topic name'     => 'Testing handlers',
        'topic'          => ':this/is/:a/:test',
        'SQL'            => 'sql statement',
        'place holders'  => [1,2,3],
        'response'       => {
            topic   => 'response/:goes/here',
            fields  => [qw(hola crayola)],
            explode => [qw(cracker)],
        },
    );

    my %hash = (
        blue   => 'azul',
        orange => 'naranja',
        red    => 'rojo',
    );

    my $json = encode_json \%hash;

    isa_ok $h, 'Machine::DB::Handler';
    isa_ok $h->responder, 'Machine::DB::Responder';

    my $data = { goes => 'is', hola => 4, crayola => undef, cracker => $json };

    my ($topic, $body) = $h->build_response($data);
    is $topic, 'response/is/here',
        'Response topic is correctly built for message with exploded fields';
    is_deeply $body, {
            hola    => 4,
            crayola => undef,
            blue    => 'azul',
            orange  => 'naranja',
            red     => 'rojo',
        }, 'Response body is correct for message with exploded fields';
}

done_testing();
