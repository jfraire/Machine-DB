use Test::More;
use strict;
use warnings;

BEGIN {
    use_ok 'Machine::DB::Handler';
    use_ok 'Machine::DB::Responder';
	use_ok 'Machine::DB::Serializer::JSON';
    use_ok 'Machine::DB::Serializer::Sereal';
    use_ok 'Machine::DB::Handler::Default';
}

done_testing();
