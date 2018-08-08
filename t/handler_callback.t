use Test::More tests => 6;
use Test::Warn;
use AnyEvent::Log;
use JSON;
use DBIx::Connector;
use strict;
use warnings;


# Note: AE::log fatal uses exit after logging to STDERR. So, it cannot
# be trapped with eval blocks. See the docs on AnyEvent::Log
# for the function AnyEvent::Log::fatal_exit.
# However, since there are cases where the code does die (isa checks)
# we need to trap everything with an eval.
# Make AE::log fatal call die instead of exit:
{
    package AnyEvent::Log;
    no warnings 'redefine';
    sub fatal_exit () { die }
}

use_ok 'Machine::DB::Handler';

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


{
    # Execute the callback. Everything should be OK
    my $crayola = int rand(1000);
    my $topic   = 'writting/is/for/Andy';
    my $msg     = encode_json { uno => 1, dos => 2, crayola => $crayola };

    $cb->($topic, $msg);

    # Check the contents of the database
    my $res = $conn->dbh->selectall_arrayref('
        SELECT hola, crayola FROM callback_test
    ');

    # note explain $res;

    is_deeply $res, [[$crayola, 'Andy']],
        'Data was inserted correctly';
}

{
    # Execute the callback. Now it will fail for undefined place holder
    my $crayola = undef;
    my $topic   = 'writting/is/for/Andy';
    my $msg     = encode_json { uno => 1, dos => 2, crayola => $crayola };

    warning_like {
        $cb->($topic, $msg);
    }
    qr/non-existant field/,
    'Callback dies when a placeholder is undefined';
}

$conn->dbh->disconnect;
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
