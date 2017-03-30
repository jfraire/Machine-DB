package Machine::DB::Handler::Default;

use parent 'Machine::DB::Handler';
use Role::Tiny::With;
use namespace::clean;
use strict;
use warnings;

with 'Machine::DB::Serializer::JSON';

1;
