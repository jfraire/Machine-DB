package Machine::DB::Serializer::JSON;

use JSON;
use Role::Tiny;
use namespace::clean;
use strict;
use warnings;

sub decode {
	my ($self, $msg) = @_;
	my $data = decode_json $msg;
}

sub encode {
    my ($self, $msg) = @_;
    return encode_json $msg;
}

1;
