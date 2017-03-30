package Machine::DB::Responder;

use Moo;
use Carp;
use namespace::clean;
use strict;
use warnings;

has topic_template => (
	is       => 'ro',
	required => 1,
    init_arg => 'topic',
);

has fields => (
    is      => 'ro',
    default => sub { [] }
);

# Builds the response MQTT topic filling the fields from $data
sub response_topic {
	my ($self, $data) = @_;

	my @topic;
	my @pieces = split qr{/}, $self->topic_template;
	foreach my $part (@pieces) {
		if (defined $part && $part =~ /^\:(\w+)/) {
			# This part is a named parameter. Substitute it by its val
			push @topic, $data->{$1};
		}
		else {
			# This part is just a constant (or empty string or undef)
			push @topic, $part;
		}
	}
	
	# Build the actual mqtt topic string
	return join '/', @topic;	
}

# Returns the hash ref to be sent via MQTT
sub response_message {
	my ($self, $data) = @_;
    my %response = map { $_ => $data->{$_} } @{$self->fields};
    return \%response;
}

1;
