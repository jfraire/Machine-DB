package Machine::DB::Default;

use parent 'Machine::DB';
use Role::Tiny::With;
use strict;
use warnings;

with 'Machine::DB::Serializer::JSON';

1;
