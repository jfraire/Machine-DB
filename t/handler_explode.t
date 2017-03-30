use Test::More tests => 2;
use Machine::DB::Handler;
use JSON;
use Sereal::Encoder;
use strict;
use warnings;

my $data = {
    this    => {red => 1, blue => 2, yellow => 3},
    a       => 'oranges',
    test    => {apples => 4, pears => 5},
    crayola => 'pineapples',
};

my $expected = {
    a       => 'oranges',
    crayola => 'pineapples',
    red     => 1, 
    blue    => 2, 
    yellow  => 3,
    apples  => 4, 
    pears   => 5,
};

my $encoder = Sereal::Encoder->new;

$data->{this} = $encoder->encode($data->{this});
$data->{test} = $encoder->encode($data->{test});

my $h = Machine::DB::Handler->new(
    'topic name'     => 'Testing handlers',
    'topic'          => ':this/is/:a/:test',
    'SQL'            => 'sql statement',
    'place holders'  => [1,2,3],
    'explode'        => [qw(this test)],
);

ok $h->has_explode_fields,
    'Handler has explode fields';

$data = $h->explode($data);
is_deeply $data, $expected,
    'Fields were exploded correctly';

done_testing();
