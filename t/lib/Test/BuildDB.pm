package Test::BuildDB;

use DBI;
use JSON;
use strict;
use warnings;
use autodie;
use v5.10;

my $db_schema = "SQL/schemaV2.sql";
my $db_data   = "SQL/insert_records.sql";
my $db_file   = "t/app_machine.db";

sub create_test_db {
    # Delete old DB if it exists
    if (-e $db_file) {
        unlink $db_file;
    }

    # Database connection
    my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", '', '', {
        AutoCommit => 1,
        RaiseError => 1
    });

    # Create test database
    {
        open my $sql, '<', $db_schema;
        local $/ = ";\n";
        while (<$sql>) {
            next unless /\S+/;
            $dbh->do($_);
        }
        close $sql;
    }
    
    # Insert test values
    {
        open my $sql, '<', $db_data;
        local $/ = ";\n";
        while (<$sql>) {
            next unless /\S+/;
            $dbh->do($_);
        }
        close $sql;
    }
    
    # Insert the current parameters. They need to be in Sereal format.
    {
        my $params = {
            stops_position           => 1370,
            brush_boolean            => 10,
            temp_doser1_sp           => 0,
            filling_bilayer_height   => 0,
            filling_height           => 4150,
            temp_doser2_sp           => 400,
        };
        
        my $sth = $dbh->prepare(
            "UPDATE machine_state SET current_params = ?
             WHERE machine_id = ?"
        );
        $sth->execute(encode_json($params), 'X12-001');
    }
    
    # Insert parameters for the two existing references. 
    # They need to be in Sereal format.
    {
        my $sth = $dbh->prepare(
            "INSERT INTO parameters (machine_type, part_number, parameters) 
             VALUES (?,?,?)"
        );
        
        my $params = {
            stops_position           => 1340,
            brush_boolean            => 10,
            temp_doser1_sp           => 0,
            temp_doser2_sp           => 350,
            filling_bilayer_height   => 0,
            filling_height           => 4100,
        };
        $sth->execute('X12', '05-0396M', encode_json($params));

        $params = {
            stops_position           => 1210,
            brush_boolean            => 10,
            temp_doser1_sp           => 0,
            temp_doser2_sp           => 400,
            filling_bilayer_height   => 0,
            filling_height           => 3000,
        };
        $sth->execute('X12', '05-0486M', encode_json($params));
    }

    $dbh->disconnect;
}

1;
