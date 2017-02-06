use Test::More;
use strict;
use warnings;

BEGIN {
    use_ok 'Machine::DB';
	use_ok 'Machine::DB::JSON';
    use_ok 'Machine::DB::Sereal';
}

my %topics = (
	'a/:b/c/d'  => ['a/+/c/d', 'a/hola/c/d', 
		{ b => 'hola' }],
	'a/:b/:c/d' => ['a/+/+/d', 'a/hola/crayola/d', 
		{ b => 'hola', c => 'crayola' }],
);

foreach my $class ( qw(JSON Sereal) ) {
    foreach my $tmpl (keys %topics) {
        my ($topic, $parser) = "Machine::DB::$class"->build_msg_parser($tmpl);
        is $topic, $topics{$tmpl}->[0],
            "$tmpl turned to $topic for subscription - $class";
        is_deeply $parser->($topics{$tmpl}->[1], ''), $topics{$tmpl}->[2],
            "$topics{$tmpl}->[1] was correctly interpreted - $class";
    }
}
done_testing();
