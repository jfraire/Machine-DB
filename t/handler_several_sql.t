use Test::More tests => 3;
use Machine::DB::Handler;
use YAML;
use strict;
use warnings;

my $config = <<YAML;
- First statement description:
    SQL: >
        UPDATE machine_state
        SET    alarm = ?
        WHERE  machine_id = ?
    place holders:
        - machine_id
        - alarm
- Second statement description:
    SQL: >
        SELECT next_reference
        FROM   machine_state
        WHERE  machine_id = ?
    place holders:
        - machine_id
YAML

my $c = Load($config);

#note explain $c;

# Constructor
my $h = Machine::DB::Handler->new(
    'topic name'     => 'Testing handlers',
    'topic'          => ':this/is/:a/:test',
    'SQL statements' => $c,
);
isa_ok $h, 'Machine::DB::Handler';

like $h->db_interactions->[0]{SQL}, qr(^UPDATE machine_state),
    'SQL statement found in correct location';
is_deeply $h->db_interactions->[1]{'place holders'}, 
    [qw(machine_id)],
    'Place holders are kept correctly';

#note explain $h->db_interactions;

done_testing();
