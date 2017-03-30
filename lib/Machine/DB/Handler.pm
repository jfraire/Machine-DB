package Machine::DB::Handler;

use Machine::DB::Responder;
use Moo;
use Carp;
use namespace::clean;
use strict;
use warnings;

sub BUILDARGS {
    my $class = shift;
    my $args;
    $args = @_ == 1 ? shift : { @_ };
    
    # Build an array ref of database interactions
	if (exists $args->{SQL}) {
        croak "Topic $args->{topic} needs place holders for $args->{SQL}"
            unless exists $args->{'place holders'};
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
);

has explode_fields => (
    is        => 'ro',
    init_arg  => 'explode',
    isa       => sub { 
        croak 'The fields to explode must be given in an array reference'
            unless ref $_[0] eq 'ARRAY';
    },
    predicate => 1,
);

has implode_fields => (
    is        => 'ro',
    init_arg  => 'implode all but',
    isa       => sub { 
        croak 'Implosion definition is not a hash reference'
            unless ref $_[0] && ref $_[0] eq 'HASH';
        croak 'Missing destination for imploded fields'
            unless exists $_[0]->{destination};
        croak 'Missing list of fields to implode'
            unless exists $_[0]->{fields} && ref $_[0]->{fields} eq 'ARRAY';
    },
    predicate => 1,
);

has responder => (
    is        => 'ro',
    handles   => [qw(response_topic response_message)],
    init_arg  => 'response',
    predicate => 1,
);

has msg_parser => (
	is  => 'lazy',
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
	$data = $obj->decode($msg) if $msg;
	croak "Message could not be decoded or it is not a hash reference"
		unless defined $data && ref $data eq 'HASH';
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
    croak "MQTT message must be a hash reference"
        unless ref $msg eq 'HASH';
    return $self->encode($msg);
}

# Returns a new hash reference with the exploded field values
sub explode {
    my ($self, $data) = @_;
    foreach my $field (@{$self->explode_fields}) {
        my $value    = delete $data->{$field};
        my $decoded  = $self->decode($value);
        croak "Exploded object could not be decoded or it is not a hash reference"
            unless defined $decoded && ref $decoded eq 'HASH';
        my %combined = (%$data, %$decoded);
        $data        = \%combined; 
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
    my $enc  = $self->encode($data);
    $imploded{$dest} = $enc;
    return \%imploded;
}

sub subscription_callback {
	my ($self, $dbh, $mqtt) = @_;
	
    # Prepare the SQL statements
    foreach my $inter (@{$self->db_interactions}) {
        $inter->{sth} = $dbh->prepare($inter->{SQL});
    }
    
	my $cb = sub {
		my ($topic, $msg) = @_;
        
        # Builds hash ref with the topic and body of the message
		my $data = $self->parse_msg($topic, $msg);
        
        # Implode data
        $self->implode($data) if $self->has_implode_fields;
        
        # Execute the list of SQL statements
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
