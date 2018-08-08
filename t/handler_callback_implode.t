use Test::More tests => 5;
use JSON;
use DBIx::Connector;
use strict;
use warnings;

use_ok 'Machine::DB::Handler';

# SQL insert statement
my $sql = <<SQL;
INSERT INTO callback_test (field1, field2)
VALUES (?, ?)
SQL

# Topic definition
my $def = {
    'topic name'     => 'Testing handlers',
    'topic'          => ':this/is/:a/:numeric',
    'SQL'            => $sql,
    'place holders'  => [qw(numeric json)],
    'implode all but' => {
        destination => 'json',
        fields      => [qw(numeric)],
    },
};

# test message
my $topic   = 'imploded/is/for/44';
my $msg     = encode_json { uno => 1, dos => 2, tres => 3 };

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
my $cb = $h->subscription_callback($conn, {});

is $st, '+/is/+/+',
    'The subscription topic is correct';
is ref($cb), 'CODE',
    'The callback for subscription is a code reference';


# Execute the callback
$cb->($topic, $msg);

# Check the contents of the database
my $res = $conn->dbh->selectall_arrayref('
    SELECT field1, field2 FROM callback_test
');

# note explain $res;
$res = $res->[0];                   # Use only first row
$res->[1] = decode_json $res->[1];  # Decode field2

my $expected = {
    uno     => 1,
    dos     => 2,
    tres    => 3,
    a       => 'for',
    this    => 'imploded',
};

is_deeply $res, [44, $expected],
    'Data was inserted correctly';

$conn->dbh->disconnect;
done_testing();

sub create_table {
    my $dbh = shift;
    $dbh->do('DROP TABLE IF EXISTS callback_test');
    $dbh->do(<<SQL);
CREATE TABLE callback_test (
    field1    INTEGER,
    field2    TEXT
);
SQL

}
