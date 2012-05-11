# vi:et:sw=4 softtabstop=4
use strict;
use warnings;
use 5.006001;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Module::Starter',
    AUTHOR              => 'Andy Lester <andy@petdance.com>',
    VERSION_FROM        => 'lib/Module/Starter.pm',
    (eval { ExtUtils::MakeMaker->VERSION(6.21) } ? (LICENSE => 'perl') : ()),
    ABSTRACT_FROM       => 'lib/Module/Starter.pm',
    EXE_FILES           => [ 'bin/module-starter' ],
    PREREQ_PM => {
        'Test::More'            => 0,
        'Test::Harness'         => 0.21,
        'ExtUtils::Command'     => 0,
        'File::Spec'            => 0,
        'Path::Class'           => 0,
        'Getopt::Long'          => 0,
        'Pod::Usage'            => 1.21,
        'parent'                => 0,
    },
    (! eval { ExtUtils::MakeMaker->VERSION(6.46) } ? () :
        (META_ADD => {
            resources => {
                homepage   => 'https://github.com/xsawyerx/module-starter',
                repository => 'https://github.com/xsawyerx/module-starter.git',
                bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Module-Starter',
            },
        })
    ),
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Module-Release-*' },
);

sub MY::postamble {
    my $postamble = <<'MAKE_FRAG';
.PHONY: tags critic

tags:
	ctags -f tags --recurse --totals \
		--exclude=blib \
		--exclude=.svn \
		--exclude='*~' \
		--languages=Perl --langmap=Perl:+.t \

critic:
	perlcritic -verbose "%f: [%p] %m at line %l, near '%r'.  (Severity: %s)\n" -q -profile perlcriticrc lib/ bin/ t/
MAKE_FRAG

    return $postamble;
}
