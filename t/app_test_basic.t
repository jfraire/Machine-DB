use Test::More tests => 4;
use JSON;
use EV;
use AnyEvent::MQTT;
use AnyEvent;
use DBI;
use strict;
use warnings;
use v5.10;

# Database connection
my $dbh = DBI->connect('dbi:SQLite:dbname=t/app_test.db', '', '', {
    AutoCommit => 1,
    RaiseError => 1
});

# Create test database
{
    local $/ = ";\n";
    while (<DATA>) {
        $dbh->do($_);
    }
}

$dbh->disconnect;

# Test that launches mqtt2db, publishes some MQTT messages, and
# then tests the contents of the DB.
my $pid = fork;
die "Could not fork: $!" unless defined $pid;
exec 'scripts/mqtt2db', '-c', 't/conf/app_basic.yaml'
    if $pid == 0;

# We're the parent. Set a timer to shut down mqtt2db
note "Launched mqtt2db with PID $pid";

my $cv = AnyEvent->condvar;

my $w = AnyEvent->timer(
    after => 3,
    cb    => sub {
        note "Stopping mqtt2db with PID $pid";
        kill 'KILL', $pid;
    }
);

# Connect to the broker
my $mqtt = AnyEvent::MQTT->new;

### Subscriptions

$mqtt->subscribe(
    topic    => 'mqtt2db/disconnected',
    callback => sub {
        my ($topic, $msg) = @_;
        state $seen = 0;
        if ($seen) {
            ok 'mqtt2db disconnected', 'Will message was received';
            $cv->send;
        }
        $seen++;
    }
);

$mqtt->subscribe(
    topic    => 'machine/15/inserted',
    callback => sub {
        my ($topic, $msg) = @_;
        my $data = decode_json($msg);
        is_deeply $data, { text_field => 'Hola' },
            'Simple SQL statements and responses are correct';
    }
);

$mqtt->subscribe(
    topic    => 'machine/33/selected',
    callback => sub {
        my ($topic, $msg) = @_;
        my $data = decode_json($msg);
        is_deeply $data, { text_field => 'Crayola' },
            'Selected data fetched from database correctly';
    }
);

$mqtt->subscribe(
    topic    => 'machine/combined',
    callback => sub {
        my ($topic, $msg) = @_;
        my $data = decode_json($msg);
        is_deeply $data, { text_field => 'Blah blah', integer_key => 15 },
            'Combined statements executed correctly';
    }
);

### Send messages

sleep 1;
my $msg = { text_field => 'Hola' };

$mqtt->publish(
    topic   => 'machine/15/insert',
    message => encode_json($msg)
);

$mqtt->publish(
    topic   => 'machine/33/select',
    message => ''
);

$mqtt->publish(
    topic   => 'machine/15/combined',
    message => ''
);

$cv->recv;
wait;
done_testing;

__DATA__

DROP TABLE IF EXISTS test_table;

CREATE TABLE test_table (
    integer_key    INTEGER,
    text_field     TEXT
);

INSERT INTO test_table (integer_key, text_field)
VALUES (33, 'Crayola');

