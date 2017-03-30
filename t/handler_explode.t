use Test::More tests => 1;
use Machine::DB::Handler::Default;
use JSON;
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

$data->{this} = encode_json $data->{this};
$data->{test} = encode_json $data->{test};

my $h = Machine::DB::Handler::Default->new(
    'topic name'     => 'Testing handlers',
    'topic'          => ':this/is/:a/:test',
    'SQL'            => 'sql statement',
    'place holders'  => [1,2,3],
    'explode'        => [qw(this test)],
);

$data = $h->explode($data);
is_deeply $data, $expected,
    'Fields were exploded correctly';

done_testing();
