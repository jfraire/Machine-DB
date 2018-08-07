package Machine::DB;

use Machine::DB::Responder;
use Machine::DB::Handler;
use AnyEvent::MQTT;
use AnyEvent::Log;
use DBIx::Connector;
use Try::Tiny;
use Moo;
use Carp;
use strict;
use warnings;
use namespace::clean;
use v5.24;
use feature qw(signatures);
no warnings qw(experimental::signatures);


our $VERSION = "0.07";

has id => (
    is       => 'rw',
    required => 1,
);

has config => (
    is       => 'rw',
    init_arg => 'configuration',
    required => 1,
);

has mqtt => (
    is => 'rw',
);

has db_connector => (
    is => 'rw',
);

# Holds a hash of response objects
has responses => (
    is => 'rw',
);


sub connect_broker ($self) {
    croak 'The configuration is missing the Broker section'
        unless defined $self->conf->{Broker};

    my $will_topic = $self->conf->{Broker}{will_topic}
        || "admin/disconnected/" . $self->id;

    AE::log 'info' => 'Connecting to broker at <'
        . $self->config->{Broker}{host}
        .'>'
        ;

    my $mqtt = AnyEvent::MQTT->new(
        will_topic   => $will_topic,
        timeout      => 10,
        will_message => '',
        will_retain  => 1,
        $self->config->{Broker}->%*,
        on_error => sub {
            my ($fatal, $msg) = @_;
            AE::log fatal => $msg if $fatal;
            AE::log error => $msg;
        }
    );

    $self->mqtt($mqtt);
}

sub connect_database ($self) {
    croak 'The configuration is missing the Database section'
        unless defined $self->conf->{Database};

    my $drv         = $self->config->{Database}{driver};
    my $dbname      = $self->config->{Database}{DBname};
    my $auto_commit = $self->config->{Database}{autoCommit} // 1;

    croak 'A database driver is required' unless $drv;
    croak 'A database name is required'   unless $dbname;
    croak 'A database user name and password are required'
        unless defined $self->config->{Database}{user}
            && defined $self->config->{Database}{password};

    AE::log 'info' => "Connecting to <$drv> database <$dbname>";

    my $conn = DBIx::Connector->new(
        "dbi:$drv:dbname=$dbname",
        $self->config->{Database}{user},
        $self->config->{Database}{password},
        { AutoCommit => $auto_commit, RaiseError => 1 });

    $self->db_connector($conn);
}

# Create list of response objects
sub build_responses ($self) {
    my %responses;
    while (my ($nam, $val) = each $self->config->{Responses}->%*) {
        AE::log 'info' => "Setting up response <$nam>";
        $val->{name} = $nam;
        my $r = Machine::DB::Responder->new(%$val);
        $responses{$nam} = $r;
    }

    $self->responses(\%responses);
}

sub start ($self) {
    croak 'The configuration does not have a Topics section'
        unless $self->conf->{Topics};

    while (my ($nam, $def) = each $self->conf->{Topics}->%*) {
        AE::log 'info' => "Setting up conversation <$nam>";

        # Load the class that should process the current topic
        my $class;
        if ($def->{'handler'}) {
            $class = "Machine::DB::Handler::" . $def->{'handler'};

            AE::log 'info' => "Loading $class for conversation <$nam>";
            eval "require $class";

            croak "Error loading class <$class>: $@"
                if $@;
        }
        else {
            $class = 'Machine::DB::Handler';
        }


        AE::log 'info' => "Instantiating handler for <$nam>";
        $def->{'topic name'} = $nam;

        # Create or load the response object
        if (exists $def->{response} && ref $def->{response}) {
            AE::log debug => "Creating response for <$nam>";

            my $r = Machine::DB::Responder->new($def->{response});

            AE::log fatal => "Failed creating the response for $nam"
                unless $r;

            $def->{response} = $r;
        }
        elsif (exists $def->{response}) {
            my $rname = $def->{response};
            AE::log fatal => "Response <$rname> does not exist"
                unless exists $self->responses->{$rname};

            $def->{response} = $self->responses->{$rname};
        }

        # Create the handler object
        my $handler = $class->new($def);

        AE::log 'info' =>
            "Subscribing to conversation <$nam> with topic <"
            . $handler->subscription_topic
            . ">"
            ;

        my $s = $self->mqtt->subscribe(
            topic    => $handler->subscription_topic,
            callback => $handler->subscription_callback(
                $self->db_connector, $self->mqtt)
        );
        $s->recv;
    }
}

sub disconnect ($self) {
    AE::log 'info' => "Disconnecting from the database";
    $self->db_connector->dbh->disconnect;

    my $will_topic   = $self->conf->{Broker}{will_topic}
        || "admin/disconnected/" . $self->id;

    my $will_message = $self->conf->{Broker}{will_message} // '';
    my $will_retain  = $self->conf->{Broker}{will_retain } // 1;

    my $s = $self->mqtt->publish(
        topic   => $will_topic,
        message => $will_message,
        retain  => $will_retain,
    );
    $s->recv;

    $self->mqtt->cleanup;
}

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
