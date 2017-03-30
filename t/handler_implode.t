use Test::More tests => 4;
use Machine::DB::Handler::Default;
use JSON;
use strict;
use warnings;

my $data = {
    this    => 'apples',
    a       => 'oranges',
    test    => 'watermelons',
    crayola => 'pineapples',
};

my $h = Machine::DB::Handler::Default->new(
    'topic name'      => 'Testing handlers',
    'topic'           => ':this/is/:a/:test',
    'SQL'             => 'sql statement',
    'place holders'   => [1,2,3],
    'implode all but' => { 
        destination => 'hola',
        fields      => [qw(crayola)],
    },
);

ok $h->has_implode_fields,
    'Handler has implode fields';

my $imploded = $h->implode($data);
ok exists $imploded->{hola},
    'The destination field was created with the implosion';
    
ok not(ref($imploded->{hola})),
    'The destination field does not contain a reference';

# note explain $imploded;
$imploded->{hola} = decode_json $imploded->{hola};



my $expected = {
    hola => {
        this => 'apples',
        a    => 'oranges',
        test => 'watermelons',
    },
    crayola => 'pineapples',
};

is_deeply $imploded, $expected,
    'Fields were imploded correctly';

done_testing();
