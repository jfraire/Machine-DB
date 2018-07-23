use Test::More tests => 6;
use JSON;
use DBIx::Connector;
use strict;
use warnings;
use_ok 'Machine::DB::Handler';

use strict;
use warnings;

# SQL insert statement
my $sql = <<SQL;
SELECT a_text FROM callback_test 
WHERE a_number = ?
SQL

# Topic definition
my $def = {
    'topic name'     => 'Testing handlers',
    'topic'          => ':a/is/:b/:c',
    'SQL'            => $sql,
    'place holders'  => ['d'],
    'response'       => {
        topic  => 'this/is/the/:a_text',
        fields => [qw(a b c d e)],
    },
};

# test message
my $topic   = 'writting/is/for/Andy';
my $msg     = encode_json { d => 33, e => 24 };

# The callback should have published the results via MQTT
my $expected = {
    topic   => 'this/is/the/Hondo',
    message => {
        a    => 'writting',
        b    => 'for',
        c    => 'Andy',
        d    => 33,
        e    => 24,
    },
};

# Mock the MQTT object
{
    package Mocked::MQTT;
    
    my $state;
    
    sub publish {
        my ($self, %args) = @_;
        $state = \%args;
        return $self;
    };
    
    sub recv { }
    
    sub report {
        return $state;
    }
}

my $mqtt = bless {}, 'Mocked::MQTT';

# Create the handler
my $h = Machine::DB::Handler->new($def);
ok ref $h, 'The handler was created successfully';

# Database connection
my $conn = DBIx::Connector->new(
    'dbi:SQLite:dbname=t/callback_test.db', '', '', {
    AutoCommit => 1,
    RaiseError => 1
});
create_table($conn->dbh);


# Actual tests
my $st = $h->subscription_topic;
my $cb = $h->subscription_callback($conn, $mqtt);

is $st, '+/is/+/+',
    'The subscription topic is correct';
is ref($cb), 'CODE',
    'The callback for subscription is a code reference';

# Execute the callback
$cb->($topic, $msg);


my $result = $mqtt->report;
$result->{message} = decode_json $result->{message};
is ref delete $result->{cv}, 'AnyEvent::CondVar',
    'The condition variable is given to the MQTT client';

#note explain $result;

is_deeply $result, $expected, 
    'The MQTT message was delivered correctly';

# note explain $result;

$conn->dbh->disconnect;
done_testing();

sub create_table {
    my $dbh = shift;
    $dbh->do('DROP TABLE IF EXISTS callback_test');
    $dbh->do(<<SQL);
CREATE TABLE callback_test (
    a_number    INTEGER,
    a_text      TEXT
);
SQL

    $dbh->do(<<SQL);
INSERT INTO callback_test (a_number, a_text)
VALUES (33, 'Hondo');
SQL

}

