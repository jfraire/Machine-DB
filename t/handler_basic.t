use Test::More tests => 7;
use Machine::DB::Handler;
use strict;
use warnings;

my $sql = 'S1';
my $i   = 1;
my @sql_statements;
foreach (1..3) {
    my %h = (SQL => $sql);
    my @ph = map { $i++ } (1..3);
    $h{'place holders'} = \@ph;
    push @sql_statements, {SQL => $sql++, 'place_holders' => \@ph};
}

# note explain \@sql_statements;

# Constructor
my $h = Machine::DB::Handler->new(
    'topic name'     => 'Testing handlers',
    'topic'          => ':this/is/:a/:test',
    'SQL statements' => \@sql_statements,
);
isa_ok $h, 'Machine::DB::Handler';

my $h1 = Machine::DB::Handler->new(
    'topic name'     => 'Testing handlers',
    'topic'          => ':this/is/:a/:test',
    'SQL'            => 'sql statement',
    'place holders'  => [1,2,3],
);
isa_ok $h1, 'Machine::DB::Handler';


# Accessors
is $h->name, 'Testing handlers',
    'Name is correct';
is $h->topic_template, ':this/is/:a/:test',
    'Topic template is correct';
is_deeply $h->db_interactions, \@sql_statements,
    'db_interactions are correct when given as array ref';
is_deeply $h1->db_interactions, [{
        SQL => 'sql statement',
        'place holders' => [1,2,3]
    }],
    'db_interactions are correct when given as a single statement';



is $h->subscription_topic, '+/is/+/+',
    'Generated MQTT topic is correct';

done_testing();
