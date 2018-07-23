package Machine::DB::Responder;

use Moo;
use Carp;
use JSON;
use AnyEvent::Log;
use List::Util qw(uniq);
use namespace::clean;
use strict;
use warnings;

my $i = 1;

has name => (
    is       => 'ro',
    default  => sub { sprintf "Response-%03d", $i++ }
);

has topic_template => (
    is       => 'ro',
    required => 1,
    init_arg => 'topic',
);

has fields => (
    is      => 'rwp',
    default => sub { [] }
);

has fields_to_explode => (
    is        => 'ro',
    init_arg  => 'explode',
    isa       => sub {
        AE::log('fatal',
            'The fields to explode must be given in an array reference'
        ) unless ref $_[0] eq 'ARRAY';
        AE::log('fatal',
            'The array reference of fields to explode cannot be empty'
        ) unless @{$_[0]} > 0;
    },
    predicate => 1,
);

sub build_response {
    my ($self, $data) = @_;
    # Because exploded fields will modify the original list of fields
    # to put in the message, save the original list and resitute it at
    # the end
    my $orig_fields = $self->fields;

    if ($self->has_fields_to_explode) {
        $data = $self->explode_fields($data);
    }

    my $topic = $self->response_topic($data);
    my $body  = $self->response_message($data);

    # Restore original list of fields
    $self->_set_fields($orig_fields);

    return $topic, $body;
}

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

sub explode_fields {
    my ($self, $data) = @_;
    foreach my $field (@{$self->fields_to_explode}) {
        my $value = delete $data->{$field};
        my $decoded;
        eval { $decoded = decode_json($value) };
        AE::log('fatal',
            "Exploded object could not be decoded or it is not a hash "
            . "reference in response <" . $self->name . ">"
        ) if $@ || !defined $decoded || ref($decoded) ne 'HASH';

        # Add exploded field contents to the list of fields to include
        # in the response
        my @fields = uniq @{$self->fields}, keys %$decoded;
        $self->_set_fields(\@fields);

        my %combined = (%$data, %$decoded);
        $data        = \%combined;
        AE::log debug => "Exploded $field: " . encode_json($decoded);
    }
    return $data;
}

1;
