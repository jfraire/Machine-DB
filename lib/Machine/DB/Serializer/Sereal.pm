package Machine::DB::Serializer::Sereal;

use Sereal::Encoder;
use Sereal::Decoder;
use Role::Tiny;
use strict;
use warnings;

my $encoder = Sereal::Encoder->new;
my $decoder = Sereal::Decoder->new;

# This method receives its class name, the parsed topic as a hash 
# reference and the contents of the MQTT message in a string. 
# It returns a hash reference with both topic and message fields.
# The message string must contain a Sereal-encoded hash reference.
sub decode_msg {
	my ($class, $msg) = @_;
	my $data = $decoder->decode($msg);
}

sub encode {
    my ($class, $msg) = @_;
    return $encoder->encode($msg);
}

1;
