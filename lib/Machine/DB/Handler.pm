package Machine::DB::Handler;

use Machine::DB::Responder;
use JSON;
use AnyEvent::Log;
use Try::Tiny;
use Moo;
use namespace::clean;
use strict;
use warnings;
use v5.24;

sub BUILDARGS {
    my $class = shift;
    my $args;
    $args = @_ == 1 ? shift : { @_ };

    # Build an array ref of database interactions
    if (exists $args->{SQL}) {
        AE::log('fatal',
            "Topic $args->{topic} needs place holders for $args->{SQL}"
        ) unless exists $args->{'place holders'};
        my %inter;
        @inter{$_} = delete $args->{$_} foreach 'SQL', 'place holders';
        $args->{'SQL statements'} = [ \%inter ];
    }

    return $args;
}

has name => (
    is       => 'ro',
    required => 1,
    init_arg => 'topic name',
);

has topic_template => (
    is       => 'ro',
    required => 1,
    init_arg => 'topic',
);

has db_interactions => (
    is       => 'ro',
    required => 1,
    init_arg => 'SQL statements',
    coerce   => sub {
        # Get rid of SQL statement descriptions
        AE::log('fatal',
            'SQL statements must be given in an array reference'
        ) unless ref $_[0] eq 'ARRAY';

        my @declarations = @{$_[0]};

        foreach (@declarations) {
            next if exists $_->{SQL} && exists $_->{'place holders'};
            ($_) = values %{$_};
        }
        $_[0] = \@declarations;
    },
    isa      => sub {
        AE::log('fatal',
            'The list of SQL statements cannot be empty'
        ) unless @{$_[0]} > 0;
        foreach my $c (@{$_[0]}) {
            AE::log('fatal',
                "SQL statements must contain the key 'SQL'"
            ) unless exists $c->{SQL};
            AE::log('fatal',
                "SQL statements must contain the key 'place holders'"
            ) unless exists $c->{'place holders'};
        }
    },
);

has implode_fields => (
    is        => 'ro',
    init_arg  => 'implode all but',
    isa       => sub {
        AE::log('fatal',
            'Implosion definition is not a hash reference'
        ) unless ref $_[0] && ref $_[0] eq 'HASH';
        AE::log('fatal',
            'Missing destination for imploded fields'
        ) unless exists $_[0]->{destination};
        AE::log('fatal',
            'Missing list of fields to implode'
        ) unless exists $_[0]->{fields} && ref $_[0]->{fields} eq 'ARRAY';
    },
    predicate => 1,
);

has responder => (
    is        => 'ro',
    handles   => [qw(response_topic response_message explode_fields
        has_fields_to_explode build_response)],
    init_arg  => 'response',
    isa       => sub {
        AE::log fatal => 'The responder was not instantiated'
            unless ref $_[0] eq 'Machine::DB::Responder';
    },
    coerce    => sub {
        my $r = ref($_[0]) ne 'Machine::DB::Responder'
            ? Machine::DB::Responder->new($_[0])
            : $_[0];
        return $r;
    },
    predicate => 1,
);

has msg_parser => (
    is  => 'lazy',
);

has preprocess_callbacks => (
    is => 'ro',
    default => sub { [] }
);

has postprocess_callbacks => (
    is => 'ro',
    default => sub { [] }
);

has msg_index => (
    is      => 'rw',
    default => sub { 0 }
);

has _cv_holder => (
    is      => 'ro',
    default => sub { +{} }
);

sub _build_msg_parser {
    my $self = shift;

    my %index_for;     # Will hold the index of named params
    my $i = 0;
    my @pieces = split qr{/}, $self->topic_template;
    foreach my $part (@pieces) {
        if (defined $part && $part =~ /^\:(\w+)/) {
            # This part is a named parameter. Keep the index
            $index_for{$1} = $i;
        }
        $i++;
    }

    # This parser looks at the topic and contents of a mqtt message and
    # it returns a hash reference of fields => values.
    my $parser = sub {
        my ($topic, $msg) = @_;
        my @pieces = split qr{/}, $topic;
        my %t = map { $_ => $pieces[$index_for{$_}] } keys %index_for;
        my $d = $self->decode_msg(\%t, $msg);
        return $d;
    };
    return $parser;
}

# This method receives the parsed topic as a hash reference and a
# string with the contents of the MQTT message.
# It must return a hash reference with both topic and message fields.
sub decode_msg {
    my ($obj, $topic_hr, $msg) = @_;
    return $topic_hr if not $msg;
    my $data;
    $data = decode_json($msg);
    unless (defined $data && ref $data eq 'HASH') {
        AE::log('error',
            "Message could not be decoded or it is not a hash reference"
        );
        return undef;
    }
    my %r = (%$data, %$topic_hr);
    return \%r;
}

sub parse_msg {
    my $self = shift;
    $self->msg_parser->(@_);
}


sub subscription_topic {
    my $self = shift;
    my $tmpl = $self->topic_template;
    $tmpl =~ s{\:([^/]+)}{+}g;
    return $tmpl;
}

sub encode_msg {
    my ($self, $msg) = @_;
    return '' unless defined $msg;
    return encode_json($msg);
}

# Builds a hash with the fields to implode, encodes it, and saves it
# in within a new key of the $data hash ref
sub implode {
    my ($self, $data) = @_;

    my %imploded;
    foreach my $field (@{$self->implode_fields->{fields}}) {
        $imploded{$field} = delete $data->{$field};
    }

    my $dest = $self->implode_fields->{destination};
    my $enc  = encode_json($data);
    $imploded{$dest} = $enc;
    AE::log debug => "Imploded $dest: $enc";
    return \%imploded;
}

sub add_to_preprocess {
    my $self = shift;
    push @{ $self->preprocess_callbacks }, @_;
}

sub add_to_postprocess {
    my $self = shift;
    push @{ $self->postprocess_callbacks }, @_;
}

sub preprocess {
    my ($self, $dbh, $data) = @_;
    foreach my $code (@{ $self->preprocess_callbacks }) {
        $code->($self, $dbh, $data);
    }
}

sub postprocess {
    my ($self, $dbh, $data) = @_;
    foreach my $code (@{ $self->postprocess_callbacks }) {
        $code->($self, $dbh, $data);
    }
}

sub publish_response {
    my ($self, $mqtt, $data) = @_;

    # Build the MQTT response
    my ($rtopic, $rmsg) = $self->build_response($data);
    $rmsg = $self->encode_msg($rmsg);

    # We need to keep the cv for pending publications,
    # and they need to clean after themselves
    my $cv  = AnyEvent->condvar;
    my $idx = $self->msg_index;
    $self->_cv_holder->{$idx} = $cv;
    $cv->cb( sub {
        delete $self->_cv_holder->{$idx};
        AE::log debug => "Deleted CV with index $idx. CV in queue: "
            . scalar keys %{ $self->_cv_holder };
    });

    # Now, let's publish the message
    AE::log debug => "Publishing to $rtopic (index $idx): $rmsg";
    $mqtt->publish(
        topic   => $rtopic,
        message => $rmsg,
        cv      => $cv
    );

    # ...and we increment the index number
    $self->msg_index(++$idx);
}

sub subscription_callback {
    my ($self, $conn, $mqtt) = @_;

    # Prepare the SQL statements
    try {
        $conn->run( fixup => sub {
            foreach my $inter (@{$self->db_interactions}) {
                $inter->{sth} = $_->prepare($inter->{SQL});
            }
        });
    }
    catch {
        AE::log fatal => $_;
    };

    my $cb = sub {
        my ($topic, $msg) = @_;

        AE::log debug => "Processing incoming message with topic <$topic>";

        # Builds hash ref with the topic and body of the message
        my $data = $self->parse_msg($topic, $msg);
        return unless $data;

        # Call pre-processing callbacks
        $self->preprocess($conn, $data);

        # Implode data
        $data = $self->implode($data) if $self->has_implode_fields;

        # Execute the list of SQL statements
        my $error;
        try {
            $conn->txn( ping => sub {
                foreach my $inter (@{$self->db_interactions}) {

                    # Get the values to bind to the sql statement
                    my @bind = map { $data->{$_} } @{$inter->{'place holders'}};
                    $inter->{sth}->execute(@bind);

                    if ($inter->{SQL} =~ /^\s*SELECT/si) {
                        # Fetch results: Only one record is allowed
                        my $rec = $inter->{sth}->fetchrow_hashref;
                        $inter->{sth}->finish;

                        # Combine fetched data with message data
                        if (defined $rec && %$rec) {
                            my %combined = (%$data, %$rec);
                            $data = \%combined;
                        }
                    }
                }
            });
        }
        catch {
            AE::log error => "Database error: $_";
            $error = 1;
        };
        return if $error;


        # Call post-processing callbacks
        $self->postprocess($conn, $data);

        # Publish a response if needed
        if ($self->has_responder) {
            AE::log debug => "Building response to <$topic>: <"
                . $self->responder->name . ">";
            $self->publish_response($mqtt, $data);
        }
    };

    return $cb;
}

1;
