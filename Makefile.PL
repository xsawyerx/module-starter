# vi:et:sw=4 softtabstop=4
use strict;
use warnings;
use 5.006001;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Module::Starter',
    AUTHOR              => 'Andy Lester <andy@petdance.com>',
    VERSION_FROM        => 'lib/Module/Starter.pm',
    (eval { ExtUtils::MakeMaker->VERSION('6.21') } ? (LICENSE => 'perl') : ()),
    (eval { ExtUtils::MakeMaker->VERSION('6.48') } ? (MIN_PERL_VERSION => '5.6.1') : ()),
    ABSTRACT_FROM       => 'lib/Module/Starter.pm',
    EXE_FILES           => [ 'bin/module-starter' ],
    PREREQ_PM => {
        'Test::More'                   => '0',
        'Test::Harness'                => '0.21',
        'ExtUtils::Command'            => '0',
        'File::Spec'                   => '0',
        'Getopt::Long'                 => '0',
        'Pod::Usage'                   => '1.21',
        'parent'                       => '0',
        'version'                      => '0',
    },
    (! eval { ExtUtils::MakeMaker->VERSION('6.46') } ? () :
        (META_MERGE => {
            dynamic_config => 0,
            'meta-spec'    => { version => 2 },
            resources      => {
                homepage   => 'https://github.com/xsawyerx/module-starter',
                repository => {
                    type => 'git',
                    url  => 'https://github.com/xsawyerx/module-starter.git',
                    web  => 'https://github.com/xsawyerx/module-starter',
                },
                bugtracker => { web => 'https://github.com/xsawyerx/module-starter/issues' },
                x_IRC      => 'irc://irc.perl.org/#toolchain',
            },
        })
    ),
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Module-Starter-*' },
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
