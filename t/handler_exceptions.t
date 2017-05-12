use Test::More;
use Test::Warn;
use Machine::DB::Handler;
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


# Tests for constructors
{
    warning_like {
            eval { my $h = Machine::DB::Handler->new(
                'topic name'     => 'Testing handlers',
                'topic'          => ':this/is/:a/:test',
                'SQL'            => 'X1',
            ) };
        }
        qr(Topic :this/is/:a/:test needs place holders),
        'Constructor dies when used with single SQL without place holders';
}

{
    warning_like {
        eval { my $h = Machine::DB::Handler->new(
            'topic name'     => 'Testing handlers',
            'topic'          => ':this/is/:a/:test',
            'SQL'            => 'sql statement',
            'place holders'  => [1,2,3],
            'explode'        => {qw(this test)},
        ) };
    }
    qr(explode must be given in an array reference),
    'When exploding fields, they must be given in an array reference';
}

{
    warning_like {
        eval { my $h = Machine::DB::Handler->new(
            'topic name'     => 'Testing handlers',
            'topic'          => ':this/is/:a/:test',
            'SQL'            => 'sql statement',
            'place holders'  => [1,2,3],
            'explode'        => [],
        ) };
    }
    qr(cannot be empty),
    'When exploding fields, the list of fields cannot be empty';
}

{
    warning_like {
        eval { my $h = Machine::DB::Handler->new(
            'topic name'      => 'Testing handlers',
            'topic'           => ':this/is/:a/:test',
            'SQL'             => 'sql statement',
            'place holders'   => [1,2,3],
            'implode all but' => [ 
                destination => 'hola',
                fields      => [qw(crayola)],
            ],
        ) };
    }
    qr(Implosion definition is not a hash reference),
    'Implosion fields must be defined in a hash reference';
}

{
    warning_like {
        eval { my $h = Machine::DB::Handler->new(
            'topic name'      => 'Testing handlers',
            'topic'           => ':this/is/:a/:test',
            'SQL'             => 'sql statement',
            'place holders'   => [1,2,3],
            'implode all but' => { 
                # destination => 'hola',
                fields      => [qw(crayola)],
            },
        ) };
    }
    qr(Missing destination for imploded fields),
    'Code dies when destination for imploded fields is missing';
}

{
    warning_like {
        eval { my $h = Machine::DB::Handler->new(
            'topic name'      => 'Testing handlers',
            'topic'           => ':this/is/:a/:test',
            'SQL'             => 'sql statement',
            'place holders'   => [1,2,3],
            'implode all but' => { 
                destination => 'hola',
                #fields      => [qw(crayola)],
            },
        ) };
    }
    qr(Missing list of fields to implode),
    'Code dies when list of fields for implosion is missing';
}

{
    warning_like {
        eval { my $h = Machine::DB::Handler->new(
            'topic name'     => 'Testing handlers',
            'topic'          => ':this/is/:a/:test',
            'encode with'    => 'Other',
            'decode with'    => 'Sereal',
            'SQL'            => 'sql statement',
            'place holders'  => [1,2,3],
            'response'       => { 
                topic  => 'response/:goes/here',
                fields => [qw(hola crayola)],
            },
        )};
    }
    qr(Unknown encoder),
    'Code dies when encoder is unknown';
}

{
    warning_like {
        eval { my $h = Machine::DB::Handler->new(
            'topic name'     => 'Testing handlers',
            'topic'          => ':this/is/:a/:test',
            'encode with'    => 'Sereal',
            'decode with'    => 'Other',
            'SQL'            => 'sql statement',
            'place holders'  => [1,2,3],
            'response'       => { 
                topic  => 'response/:goes/here',
                fields => [qw(hola crayola)],
            },
        )};
    }
    qr(Unknown decoder),
    'Code dies when decoder is unknown';
}

# Tests for runtime errors
{
    warning_like {
        my $h = Machine::DB::Handler->new(
            'topic name'     => 'Testing handlers',
            'topic'          => ':this/is/:a/:test',
            'encode with'    => 'Sereal',
            'decode with'    => 'JSON',
            'SQL'            => 'sql statement',
            'place holders'  => [1,2,3],
            'response'       => { 
                topic  => 'response/:goes/here',
                fields => [qw(hola crayola)],
            },
        );
        
        $h->decode_msg({this => 'Failing'}, '["Fail"]');
    }
    qr(is not a hash reference),
    'Handler reports a bad message if contents are not in a hash';
}
    
done_testing();