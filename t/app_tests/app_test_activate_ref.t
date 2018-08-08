use Test::More tests => 2;
use lib 't/lib';
use POSIX ':sys_wait_h';
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
if ($pid == 0) {
    exec 'scripts/mqtt2db', '-c', 't/conf/app_machine.yaml'
        || die "Could not launch mqtt2db";
    exit 0;
}

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

my $cvs = $mqtt->subscribe(
    topic    => 'presses/X12/X12-001/parameters/set',
    callback => sub {
        my ($topic, $msg) = @_;
        my $data = decode_json($msg);
#        note $msg;
        is_deeply $data, {
            stops_position           => 1210,
            brush_boolean            => 10,
            temp_doser1_sp           => 0,
            temp_doser2_sp           => 400,
            filling_bilayer_height   => 0,
            filling_height           => 3000,
        },
            'New parameters received correctly';
    }
);
$cvs->recv;

$cvs = $mqtt->subscribe(
    topic    => 'presses/X12/X12-001/reference/set',
    callback => sub {
        my ($topic, $msg) = @_;
        my $data = decode_json($msg);
        is_deeply $data, { part_number => '05-0486M' },
            'Reference was activated correctly';
    }
);
$cvs->recv;



### Send messages

sleep 1; # Wait for mqtt2db to start

$cvs = $mqtt->publish(
    topic   => 'presses/X12/X12-001/next/activate',
    message => ''
);
$cvs->recv;

$cvs = $mqtt->publish(
    topic   => 'presses/X12/X12-001/reference/get',
    message => ''
);
$cvs->recv;

$cv->recv;
note "Waiting for child to quit";
1 while waitpid($pid, WNOHANG) > 0;
done_testing;
