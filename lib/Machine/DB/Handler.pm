package Machine::DB::Handler;

use Machine::DB::Responder;
use JSON;
use Sereal::Encoder;
use Sereal::Decoder;
use AnyEvent::Log;
use Moo;
use namespace::clean;
use strict;
use warnings;
use v5.24;

my $sereal_encoder = Sereal::Encoder->new;
my $sereal_decoder = Sereal::Decoder->new;

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
    
    # Build a responder object
    if (exists $args->{response}) {
        $args->{response} =  Machine::DB::Responder->new(
            $args->{response}
        );
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

has explode_fields => (
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
    handles   => [qw(response_topic response_message)],
    init_arg  => 'response',
    predicate => 1,
);

has decode_msg_with => (
    is        => 'ro',
    init_arg  => 'decode with',
    default   => 'JSON',
    isa       => sub { 
        AE::log('fatal', 
            "Unknown decoder: $_[0]" 
        ) unless ($_[0] eq 'JSON' || $_[0] eq 'Sereal');
    },
);

has encode_msg_with => (
    is        => 'ro',
    init_arg  => 'encode with',
    default   => 'JSON',
    isa       => sub { 
        AE::log('fatal', 
            "Unknown encoder: $_[0]" 
        ) unless ($_[0] eq 'JSON' || $_[0] eq 'Sereal');
    },
);

has msg_parser => (
	is  => 'lazy',
);

has msg_decoder => (
    is => 'lazy',
);

has msg_encoder => (
    is => 'lazy',
);

has preprocess_callbacks => (
    is => 'ro',
    default => sub { [] }
);

has postprocess_callbacks => (
    is => 'ro',
    default => sub { [] }
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

sub _build_msg_decoder {
    my $self = shift;
    if ($self->decode_msg_with eq 'Sereal') {
        return sub { return $sereal_decoder->decode(shift) };
    }
    elsif ($self->decode_msg_with eq 'JSON') {
        return sub { return decode_json(shift) };
    }
}

sub _build_msg_encoder {
    my $self = shift;
    if ($self->decode_msg_with eq 'Sereal') {
        return sub { return $sereal_encoder->encode(shift) };
    }
    elsif ($self->decode_msg_with eq 'JSON') {
        return sub { return encode_json(shift) };
    }
}

# This method receives the parsed topic as a hash reference and a 
# string with the contents of the MQTT message. 
# It must return a hash reference with both topic and message fields.
sub decode_msg {
	my ($obj, $topic_hr, $msg) = @_; 
    return $topic_hr if not $msg;
	my $data;
	$data = $obj->msg_decoder->($msg);
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
    return $self->msg_encoder->($msg);
}

# Returns a new hash reference with the exploded field values
sub explode {
    my ($self, $data) = @_;
    foreach my $field (@{$self->explode_fields}) {
        my $value    = delete $data->{$field};
        my $decoded;
        eval { $decoded = $sereal_decoder->decode($value) };
        AE::log('fatal',
            "Exploded object could not be decoded or it is not a hash reference"
        ) if $@ || !defined $decoded || ref($decoded) ne 'HASH';
        my %combined = (%$data, %$decoded);
        $data        = \%combined; 
        AE::log debug => "Exploded $field: " . encode_json($decoded);
    }
    return $data;
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
    my $enc  = $sereal_encoder->encode($data);
    $imploded{$dest} = $enc;
    AE::log debug => "Imploded $dest: " . encode_json($data);
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

sub subscription_callback {
	my ($self, $dbh, $mqtt) = @_;
	
    # Prepare the SQL statements
    foreach my $inter (@{$self->db_interactions}) {
        $inter->{sth} = $dbh->prepare($inter->{SQL});
    }
    
	my $cb = sub {
		my ($topic, $msg) = @_;

        AE::log debug => "Processing incoming message with topic $topic";
        
        # Builds hash ref with the topic and body of the message
		my $data = $self->parse_msg($topic, $msg);
        return unless $data;
        
        # Call pre-processing callbacks
        $self->preprocess($dbh, $data);
        
        # Implode data
        $data = $self->implode($data) if $self->has_implode_fields;
        
        # Execute the list of SQL statements
        foreach my $inter (@{$self->db_interactions}) {
            
            # Get the values to bind to the sql statement
            my @bind = map { $data->{$_} } @{$inter->{'place holders'}};
            $inter->{sth}->execute(@bind);
            AE::log error => $DBI::errstr if $DBI::errstr;
            
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
        
        # Call post-processing callbacks
        $self->postprocess($dbh, $data);
        
        # Build the response
        if ($self->has_responder) {
            $data = $self->explode($data) if $self->has_explode_fields;
            my $rtopic = $self->response_topic($data);
            my $rmsg   = $self->response_message($data);
            $rmsg      = $self->encode_msg($rmsg);
            my $cv = $mqtt->publish(topic => $rtopic, message => $rmsg);
            $cv->recv;
        }
	};
	
	return $cb;
}

1;
