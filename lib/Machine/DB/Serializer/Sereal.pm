package Machine::DB::Serializer::Sereal;

use Sereal::Encoder;
use Sereal::Decoder;
use Role::Tiny;
use strict;
use warnings;

my $encoder = Sereal::Encoder->new;
my $decoder = Sereal::Decoder->new;

sub decode {
	my ($class, $msg) = @_;
	my $data = $decoder->decode($msg);
}

sub encode {
    my ($class, $msg) = @_;
    return $encoder->encode($msg);
}

1;
