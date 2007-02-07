# vi:et:sw=4 softtabstop=4
use strict;
use warnings;
use 5.6.1;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Module::Starter',
    AUTHOR              => 'Andy Lester <andy@petdance.com>',
    VERSION_FROM        => 'lib/Module/Starter.pm',
    ABSTRACT_FROM       => 'lib/Module/Starter.pm',
    EXE_FILES           => [ 'bin/module-starter' ],
    PREREQ_PM => {
        'Test::More'            => 0,
        'ExtUtils::Command'     => 0,
        'File::Spec'            => 0,
        'Getopt::Long'          => 0,
        'Pod::Usage'            => 0,
    },
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
	perlcritic -1 -q -profile perlcriticrc bin/ lib/ t/
MAKE_FRAG

    return $postamble;
}
