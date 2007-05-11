use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Foo::Bar',
    AUTHOR              => 'C.J. Adams-Collier <cjac@colliertech.org>',
    VERSION_FROM        => 'lib/Foo/Bar.pm',
    ABSTRACT_FROM       => 'lib/Foo/Bar.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Foo-Bar-*' },
);
