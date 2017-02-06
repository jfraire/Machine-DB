package Machine::DB;

use strict;
use warnings;

our $VERSION = "0.01";


# Builds the MQTT topic string for suscription and a message parser
sub build_msg_parser {
	my ($class, $tmpl) = @_;
	
	my @topic;         # Will hold the pieces of the mqtt topic string
	my %index_for;     # Will hold the index of named params
	my $i = 0;
	my @pieces = split qr{/}, $tmpl;
	foreach my $part (@pieces) {
		if (defined $part && $part =~ /^\:(\w+)/) {
			# This part is a named parameter. Keep the index and
			# put a wildcard in the mqtt topic
			$index_for{$1} = $i;
			push @topic, '+';
		}
		else {
			# This part is just a constant (or empty string or undef)
			push @topic, $part;
		}
		$i++;
	}
	
	# Build the actual mqtt topic string
	my $mqtt_topic = join '/', @topic;
	
	# This parser looks the topic and contents of a mqtt message and
	# it returns a hash reference of fields => values.
	# Note that the message decoder is sub-classable
	my $parser = sub {
		my ($topic, $msg) = @_;
		my @pieces = split qr{/}, $topic;
		my %t = map { $_ => $pieces[$index_for{$_}] } keys %index_for;
		my $d = $class->decode_msg(\%t, $msg);
		return $d;
	};
	return $mqtt_topic, $parser;
}

sub fill_topic_template {
	my ($class, $tmpl, $data) = @_;

	my @topic;
	my @pieces = split qr{/}, $tmpl;
	foreach my $part (@pieces) {
		if (defined $part && $part =~ /^\:(\w+)/) {
			# This part is a named parameter. Substitute it by its val
			push @topic, $data->{$part};
		}
		else {
			# This part is just a constant (or empty string or undef)
			push @topic, $part;
		}
	}
	
	# Build the actual mqtt topic string
	return join '/', @topic;	
}

sub build_callback {
	my ($class, $mqtt, $dbh, $def) = @_;
	
	# Build MQTT topic string and message parser
	my $tmpl = $def->{topic};
	my ($mqtt_topic, $msg_parser) = $class->build_msg_parser($tmpl);
	
	# Prepare database statement holder
	my $sth = $dbh->prepare($def->{SQL});
	
	# The callback parses the message, calls an eventual data processor,
	# builds the array of place holders, and executes the SQL statement
	my $cb = sub {
		my ($topic, $msg) = @_;
		my $data = $msg_parser->($topic, $msg);
		my $proc = $class->process_data($def, $data);
		my @bind_values = 
			map { $proc->{$_} } 
			@{$def->{'place holders'}};
		$sth->execute(@bind_values);
		if ($def->{response}) {
			# fetch data and send it back
			my $array_ref = $sth->fetchall_arrayref({});
			my $resp_topic = $class->fill_topic_template(
				$def->{topic}, 
				$proc
			);
			my $enc_msg = $class->encode_msg($array_ref->[0]);
			my $v = $mqtt->publish( 
				topic   => $resp_topic,
				message => $enc_msg
			);
			$v->recv;
		}
	};
	return $mqtt_topic, $cb;
}

# This method must be subclassed. It receives its class name, the
# parsed topic as a hash reference and a string with the contents of
# the MQTT message. 
# It must return a hash reference with both topic and message fields.
sub decode_msg {
	my ($class, $topic_hr, $msg) = @_; 
	my $data;
	$data = $class->decode($msg) if $msg;
	croak "Message could not be decoded"
		unless defined $data && ref $data eq 'HASH';
	my %r = (%$data, %$topic_hr);
    return \%r;
}

sub encode_msg {
    my ($class, $msg) = @_;
    return '' unless defined $msg && ref $msg eq 'HASH';
    return $class->encode($msg);
}

# This method must return a hash reference with the field, value pairs
# needed to execute the SQL statement holder.
# It receives the class name, configuration section for the given topic,
# and a hash reference that results from parsing the message.
# The default implementation does not modify the input hash ref.
sub process_data { return $_[2] }
sub process_results { return $_[2] }

1;
__END__

=pod

=encoding utf-8

=head1 NAME

Machine::DB - T

=head1 SYNOPSIS

    use Machine::DB;

=head1 DESCRIPTION

Machine::DB is ...

=head1 LICENSE

Copyright (C) Julio Fraire.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Julio Fraire E<lt>julio.fraire@gmail.comE<gt>

=cut

