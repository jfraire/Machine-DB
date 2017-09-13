use 5.020000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Machine::DB',
    VERSION_FROM      => 'lib/Machine/DB.pm',
    PREREQ_PM         => {
        'YAML'             => 1.23,
        'Try::Tiny'        => 0.28,
        'EV'               => 4.22,
        'AnyEvent'         => 7.14,
        'AnyEvent::MQTT'   => 1.17,
        'DBI'              => 1.637,
        'JSON'             => 2.94,
        'Moo'              => 2.003,
        'namespace::clean' => 0.27,
        'Sereal::Encoder'  => 3.015,
        'Sereal::Decoder'  => 3.015,        
    },
    ABSTRACT_FROM     => 'lib/Machine/DB.pm',
    AUTHOR            => 'Julio Fraire <julio@gmail.com>',
    LICENSE           => 'perl',
    #Value must be from legacy list of licenses here
    #http://search.cpan.org/perldoc?Module%3A%3ABuild%3A%3AAPI
);
