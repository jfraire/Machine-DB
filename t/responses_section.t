use Test::More tests => 9;
use YAML::XS qw(LoadFile);
use JSON;
use strict;
use warnings;

use_ok 'Machine::DB';

my $config = LoadFile('t/conf/with_response.yaml');

my $mdb = Machine::DB->new(
    id            => 'test',
    configuration => $config
);

isa_ok $mdb, 'Machine::DB';

$mdb->build_responses;

my $r = $mdb->responses->{'Send reference'};
isa_ok $r, 'Machine::DB::Responder';

is $r->name, 'Send reference',
    'Responder name is correct';

is $r->topic_template, 'machine/:machine_id/reference/set',
    'Responder topic is correct';

is_deeply $r->fields, [ 'part_number' ],
    'Fields are in an array and it is correct';

is_deeply $r->fields_to_explode, [ 'parameters' ],
    'Fields to explode are in an array and it is correct';

my %parameters = (
    temperature => 100,
    time        => 600,
);

my $data = {
    machine_id  => 'S22-004',
    part_number => 'Huevo cocido',
    parameters  => encode_json(\%parameters),
};

my ($topic, $body) = $r->build_response($data);

is $topic, 'machine/S22-004/reference/set',
    'Topic was built correctly';

is_deeply $body, {
    part_number => 'Huevo cocido',
    temperature => 100,
    time        => 600,
}, 'Message body was built correctly';

done_testing();
