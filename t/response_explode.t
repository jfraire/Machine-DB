use Test::More;
use AnyEvent::Log;
use Test::Warn;
use JSON;
use strict;
use warnings;

# Note: AE::log fatal uses exit after logging to STDERR. So, it cannot
# be trapped with eval blocks. See the docs on AnyEvent::Log
# for the function AnyEvent::Log::fatal_exit.
# However, since there are cases where the code does die (isa checks)
# we need to trap everything with an eval.
# Make AE::log fatal call die instead of exit:
{
    no warnings 'redefine';
    sub AnyEvent::Log::fatal_exit () { die };
}

use_ok 'Machine::DB::Responder';

my $r = Machine::DB::Responder->new(
    topic   => 'this/is/:a/:blue',
    fields  => [qw(hola crayola)],
    explode => [qw(cracker)],
);

{
    # Case all is good
    my %hash = (
        blue   => 'azul',
        orange => 'naranja',
        red    => 'rojo',
    );

    my $data = {
        a       => 1,
        test    => 2,
        hola    => 3,
        crayola => 4,
        cracker => encode_json(\%hash),
    };

    is $r->topic_template, 'this/is/:a/:blue',
        'Topic template is read correctly';

    my ($topic, $body) = $r->build_response($data);

    is $topic, 'this/is/1/azul',
        'Response topic is built correctly';

    is_deeply $body, {
        hola    => 3,
        crayola => 4,
        blue    => 'azul',
        orange  => 'naranja',
        red     => 'rojo' },
        'Response message is built correctly';
}

{
    # This fails because field to explode is not a hash
    my @not_a_hash = (
        blue   => 'azul',
        orange => 'naranja',
        red    => 'rojo',
    );

    my $data = {
        a       => 1,
        test    => 2,
        hola    => 3,
        crayola => 4,
        cracker => encode_json(\@not_a_hash),
    };

    warning_like {
        eval { $r->build_response($data) }
    }
    qr/is not a hash reference/,
    'Exploding fields must contain hash references or code dies';
}

{
    # This fails because field to explode is not JSON

    my $data = {
        a       => 1,
        test    => 2,
        hola    => 3,
        crayola => 4,
        cracker => 'Not a JSON string',
    };

    warning_like {
        eval { $r->build_response($data) }
    }
    qr/could not be decoded/,
    'Exploding fields must be JSON encoded hashes';
}

{
    # This fails because field to explode is not JSON

    my $data = {
        a       => 1,
        test    => 2,
        hola    => 3,
        crayola => 4,
        cracker => 'null',
    };

    warning_like {
        eval { $r->build_response($data) }
    }
    qr/could not be decoded/,
    'A null JSON string cannot be used as exploding field';
}

done_testing();
