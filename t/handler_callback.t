use Test::More;
use JSON;
use DBI;
use strict;
use warnings;

use_ok 'Machine::DB::Handler::Default';

# SQL insert statement
my $sql = <<SQL;
INSERT INTO callback_test (hola, crayola)
VALUES (?, ?)
SQL

# Topic definition
my $def = {
    'topic name'     => 'Testing handlers',
    'topic'          => ':this/is/:a/:test',
    'SQL'            => $sql,
    'place holders'  => [qw(crayola test)],
};

# test message
my $crayola = int rand(1000);
my $topic   = 'writting/is/for/Andy';
my $msg     = encode_json { uno => 1, dos => 2, crayola => $crayola };

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
my $cb = $h->subscription_callback($dbh, {});

is $st, '+/is/+/+',
    'The subscription topic is correct';
is ref($cb), 'CODE',
    'The callback for subscription is a code reference';


# Execute the callback
$cb->($topic, $msg);

# Check the contents of the database
my $res = $dbh->selectall_arrayref('
    SELECT hola, crayola FROM callback_test
');

# note explain $res;

is_deeply $res, [[$crayola, 'Andy']],
    'Data was inserted correctly';


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

}
