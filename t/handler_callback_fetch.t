use Test::More tests => 5;
use JSON;
use DBI;
use strict;
use warnings;

use_ok 'Machine::DB::Handler::Default';

# SQL insert statement
my $sql = <<SQL;
SELECT * FROM callback_test 
WHERE hola = ?
SQL

# Topic definition
my $def = {
    'topic name'     => 'Testing handlers',
    'topic'          => ':this/is/:a/:test',
    'SQL'            => $sql,
    'place holders'  => [qw(hola)],
    'response'       => {
        topic  => 'this/is/the/:crayola',
        fields => [qw(this a test hola dos)],
    },
};

# test message
my $topic   = 'writting/is/for/Andy';
my $msg     = encode_json { hola => 33, dos => 2 };

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
my $h = Machine::DB::Handler::Default->new($def);
ok ref $h, 'The handler was created successfully';

# Database connection
my $dbh = DBI->connect('dbi:SQLite:dbname=t/callback_test.db', '', '', {
    AutoCommit => 1,
    RaiseError => 1
});
create_table($dbh);


# Actual tests
my $st = $h->subscription_topic;
my $cb = $h->subscription_callback($dbh, $mqtt);

is $st, '+/is/+/+',
    'The subscription topic is correct';
is ref($cb), 'CODE',
    'The callback for subscription is a code reference';

# Execute the callback
$cb->($topic, $msg);


# The callback should have published the results via MQTT
my $expected = {
    topic   => 'this/is/the/Hondo',
    message => {
        this    => 'writting',
        a       => 'for',
        test    => 'Andy',
        hola    => 33,
        dos     => 2,
    },
};
my $result = $mqtt->report;
$result->{message} = decode_json $result->{message};

is_deeply $result, $expected, 
    'The MQTT message was delivered correctly';

# note explain $result;

$dbh->disconnect;
done_testing();

sub create_table {
    my $dbh = shift;
    $dbh->do('DROP TABLE IF EXISTS callback_test');
    $dbh->do(<<SQL);
CREATE TABLE callback_test (
    hola    INTEGER,
    crayola TEXT
);
SQL

    $dbh->do(<<SQL);
INSERT INTO callback_test (hola, crayola)
VALUES (33, 'Hondo');
SQL

}
