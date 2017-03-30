use Test::More tests => 5;
use Sereal::Encoder;
use Sereal::Decoder;
use strict;
use warnings;

use_ok 'Machine::DB::Handler';

my $encoder = Sereal::Encoder->new;
my $decoder = Sereal::Decoder->new;

my $h = Machine::DB::Handler->new(
    'topic name'     => 'Testing handlers',
    'topic'          => ':this/is/:a/:test',
    'encode with'    => 'Sereal',
    'decode with'    => 'Sereal',
    'SQL'            => 'sql statement',
    'place holders'  => [1,2,3],
    'response'       => { 
        topic  => 'response/:goes/here',
        fields => [qw(hola crayola)],
    },
);

# Decoding side
is $h->decode_msg_with, 'Sereal',
    'decode with declared correctly as Sereal';

my %expected = ( hola => 1, crayola => 2 ); 
my $msg = $encoder->encode(\%expected);

is_deeply $h->msg_decoder->($msg), \%expected,
    'The message decoder worked OK with Sereal';

# Encoding side
is $h->encode_msg_with, 'Sereal',
    'encode with declared correctly as Sereal';

my $enc = $h->msg_encoder->(\%expected);
my $decoded = $decoder->decode($enc);

is_deeply $decoded, \%expected,
    'The message encoder worked OK with Sereal';

done_testing();
