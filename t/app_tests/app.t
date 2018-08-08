use Test::More tests => 4;
use POSIX ':sys_wait_h';
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
note "Connected to the database";

# Create test database
{
    local $/ = ";\n";
    while (<DATA>) {
        $dbh->do($_);
    }
}

$dbh->disconnect;
note "Created the test database";

# Test that launches mqtt2db, publishes some MQTT messages, and
# then tests the contents of the DB.
note "Forking";
my $pid = fork;
die "Could not fork: $!" unless defined $pid;

if ($pid == 0) {
    exec('scripts/mqtt2db', '-c', 't/conf/app_basic.yaml') 
        || die 'Could not execute scripts/mqtt2db';
    exit 0;
}
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

# Connect to the broker at localhost
my $mqtt = AnyEvent::MQTT->new;

### Subscriptions

my $cvs = $mqtt->subscribe(
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
$cvs->recv;

$cvs = $mqtt->subscribe(
    topic    => 'machine/15/inserted',
    callback => sub {
        my ($topic, $msg) = @_;
        my $data = decode_json($msg);
        is_deeply $data, { text_field => 'Hola' },
            'Simple SQL statements and responses are correct';
    }
);
$cvs->recv;

$cvs = $mqtt->subscribe(
    topic    => 'machine/33/selected',
    callback => sub {
        my ($topic, $msg) = @_;
        my $data = decode_json($msg);
        is_deeply $data, { text_field => 'Crayola' },
            'Selected data fetched from database correctly';
    }
);
$cvs->recv;

$cvs = $mqtt->subscribe(
    topic    => 'machine/combined',
    callback => sub {
        my ($topic, $msg) = @_;
        my $data = decode_json($msg);
        is_deeply $data, { text_field => 'Blah blah', integer_key => 15 },
            'Combined statements executed correctly';
    }
);
$cvs->recv;

### Send messages

sleep 1; # Wait for mqtt2db to start

my $msg = { text_field => 'Hola' };

$cvs = $mqtt->publish(
    topic   => 'machine/15/insert',
    message => encode_json($msg)
);
$cvs->recv;

$cvs = $mqtt->publish(
    topic   => 'machine/33/select',
    message => ''
);
$cvs->recv;

$cvs = $mqtt->publish(
    topic   => 'machine/15/combined',
    message => ''
);
$cvs->recv;

$cv->recv;
1 while waitpid($pid, WNOHANG) > 0;
done_testing;

__DATA__

DROP TABLE IF EXISTS test_table;

CREATE TABLE test_table (
    integer_key    INTEGER,
    text_field     TEXT
);

INSERT INTO test_table (integer_key, text_field)
VALUES (33, 'Crayola');

