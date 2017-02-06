package Machine::DB::Serializer::JSON;

use JSON;
use Role::Tiny;
use strict;
use warnings;

# This method receives its class name, the parsed topic as a hash 
# reference and the contents of the MQTT message in a string. 
# It returns a hash reference with both topic and message fields.
# The message string must contain a JSON object
sub decode_msg {
	my ($class, $msg) = @_;
	my $data = json_decode $msg;
}

sub encode {
    my ($class, $msg) = @_;
    return json_encode $msg;
}

1;
