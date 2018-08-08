use Test::More tests => 3;
use lib 't/lib';
use Test::BuildDB;
use JSON;
use EV;
use AnyEvent::MQTT;
use AnyEvent;
use strict;
use warnings;
use v5.10;

Test::BuildDB->create_test_db;

# Test that launches mqtt2db, publishes some MQTT messages, and
# then tests the contents of the DB.
my $pid = fork;
die "Could not fork: $!" unless defined $pid;
exec 'scripts/mqtt2db', '-c', 't/conf/app_machine.yaml'
    if $pid == 0;

# We're the parent. Set a timer to shut down mqtt2db
note "Launched mqtt2db with PID $pid";

my $cv = AnyEvent->condvar;

# Connect to the broker at localhost
my $mqtt = AnyEvent::MQTT->new;

my $w = AnyEvent->timer(
    after => 5,
    cb    => sub {
        note "Stopping mqtt2db with PID $pid";
        kill 'KILL', $pid;
        $cv->send;
    }
);

### Subscriptions

$mqtt->subscribe(
    topic    => 'presses/X12/X12-001/reference/set',
    callback => sub {
        my ($topic, $msg) = @_;
        my $data = decode_json($msg);
        is_deeply $data, { part_number => '05-0396M' },
            'Received current reference correctly';
    }
);

$mqtt->subscribe(
    topic    => 'presses/X12/X12-001/next/set',
    callback => sub {
        my ($topic, $msg) = @_;
        my $data = decode_json($msg);
        is_deeply $data, { next_item => '05-0486M' },
            'Received next reference correctly';
    }
);

$mqtt->subscribe(
    topic    => 'presses/X12/X12-001/parameters/set',
    callback => sub {
        my ($topic, $msg) = @_;
        my $data = decode_json($msg);
        is_deeply $data, {
            stops_position           => 1370,
            brush_boolean            => 10,
            temp_doser1_sp           => 0,
            temp_doser2_sp           => 400,
            filling_height           => 4150,
            filling_bilayer_height   => 0,
        },
            'Received current parameters correctly';
    }
);

### Send messages

sleep 1;

$mqtt->publish(
    topic   => 'presses/X12/X12-001/reference/get',
    message => ''
);

$mqtt->publish(
    topic   => 'presses/X12/X12-001/next/get',
    message => ''
);

$mqtt->publish(
    topic   => 'presses/X12/X12-001/parameters/get',
    message => ''
);

$cv->recv;
note "Waiting for child to quit";
wait;
done_testing;
