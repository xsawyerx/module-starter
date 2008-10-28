#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 61;

use Module::Starter;
use File::Spec;
use File::Path;
use Carp;

sub chomp_me {
    my $string = shift;
    chomp($string);
    return $string;
}

package TestParseFile;

use Test::More;

sub new {
    my $class = shift;
    my $self = {};

    bless $self, $class;

    $self->_init(@_);

    return $self;
}

sub _filename {
    my $self = shift;

    $self->{_filename} = shift if @_;

    return $self->{_filename};
}

sub _text {
    my $self = shift;

    $self->{_text} = shift if @_;

    return $self->{_text};
}

sub _init {
    my ($self, $args) = @_;

    $self->_filename($args->{fn});

    $self->_text(_slurp_to_ref($self->_filename()));

    return;
}

sub _slurp_to_ref {
    my $filename = shift;
    my $text;

    local $/;
    open my $in, '<', $filename
        or Carp::confess( "Cannot open file $filename: $!" );
    $text = <$in>;
    close($in);

    return \$text;
}

sub parse {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ($self, $re, $msg) = @_;

    my $verdict = ok (scalar(${$self->_text()} =~ s{$re}{}ms), $self->format_msg($msg));

    if ( !$verdict ) {
        diag("Filename == " . $self->_filename());
    }

    return $verdict;
}

sub consume {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ($self, $prefix, $msg) = @_;

    my $verdict =
        is( substr(${$self->_text()}, 0, length($prefix)),
            $prefix,
            $self->format_msg($msg));

    if ($verdict) {
        ${$self->_text()} = substr(${$self->_text()}, length($prefix));
    }
    else {
        diag("Filename == " . $self->_filename());
    }

    return $verdict;
}

sub is_end {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ($self, $msg) = @_;

    my $verdict = is (${$self->_text()}, "", $self->format_msg($msg));

    if ( !$verdict ) {
        diag("Filename == " . $self->_filename());
    }

    return $verdict;
}

=head2 $file_parser->parse_paras(\@paras, $message)

Parse the paragraphs paras. Paras can either be strings, in which case
they'll be considered plain texts. Or they can be hash refs with the key
're' pointing to a regex string.

Here's an example:

    my @synopsis_paras = (
        '=head1 SYNOPSIS',
        'Quick summary of what the module does.',
        'Perhaps a little code snippet.',
        { re => q{\s*} . quotemeta(q{use MyModule::Test;}), },
        { re => q{\s*} .
            quotemeta(q{my $foo = MyModule::Test->new();})
            . q{\n\s*} . quotemeta("..."), },
    );

    $mod1->parse_paras(
        \@synopsis_paras,
        'MyModule::Test - SYNOPSIS',
    );

=cut

sub parse_paras {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ($self, $paras, $msg) = @_;

    # Construct a large regex.
    my $regex =
        join '',
        map { $_.q{\n\n+} }
        map { (ref($_) eq 'HASH') ? $_->{re} : quotemeta($_) }
        @{$paras};

    return $self->parse(
        $regex,
        $msg,
    );
}

sub format_msg {
    my ($self, $msg) = @_;

    return $msg;
}

package TestParseModuleFile;

use vars qw(@ISA);

@ISA = qw(TestParseFile);

sub _perl_name {
    my $self = shift;

    $self->{_perl_name} = shift if @_;

    return $self->{_perl_name};
}

sub _dist_name {
    my $self = shift;

    $self->{_dist_name} = shift if @_;

    return $self->{_dist_name};
}

sub _init {
    my ($self, $args) = @_;

    $self->SUPER::_init($args);

    $self->_perl_name($args->{perl_name});

    $self->_dist_name($args->{dist_name});

    return;
}

sub format_msg {
    my ($self, $msg) = @_;

    return $self->_perl_name() . " - $msg";
}

# TEST:$cnt=0;
sub parse_module_start {
    my $self = shift;

    my $perl_name = $self->_perl_name();
    my $dist_name = $self->_dist_name();
    my $lc_dist_name = lc($dist_name);

    # TEST:$cnt++;
    $self->parse(
        qr/\Apackage \Q$perl_name\E;\n\nuse warnings;\nuse strict;\n\n/ms,
        "start",
    );

    {
        my $s1 = qq{$perl_name - The great new $perl_name!};

        # TEST:$cnt++;
        $self->parse(
            qr/\A=head1 NAME\n\n\Q$s1\E\n\n/ms,
            'NAME Pod.',
        );
    }

    # TEST:$cnt++;
    $self->parse(
        qr/\A=head1 VERSION\n\nVersion 0\.01\n\n=cut\n\nour \$VERSION = '0\.01';\n+/,
        'module version',
    );

    {
        my @synopsis_paras =
        (
            '=head1 SYNOPSIS',
            'Quick summary of what the module does.',
            'Perhaps a little code snippet.',
            { re => q{\s*} . quotemeta(qq{use $perl_name;}), },
            { re => q{\s*} .
                quotemeta(q{my $foo = } . $perl_name . q{->new();})
                . q{\n\s*} . quotemeta("..."),
            },
        );

        # TEST:$cnt++
        $self->parse_paras(
            \@synopsis_paras,
            'SYNOPSIS',
        );
    }

    # TEST:$cnt++
    $self->parse_paras(
        [
            '=head1 EXPORT',
            (
"A list of functions that can be exported.  You can delete this section\n"
. "if you don't export anything, such as for a purely object-oriented module."
            ),
        ],
        'EXPORT',
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            '=head1 FUNCTIONS',
            '=head2 function1',
            '=cut',
            "sub function1 {\n}",
        ],
        'function1',
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            '=head2 function2',
            '=cut',
            "sub function2 {\n}",
        ],
        'function2',
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            '=head1 AUTHOR',
            { re => q{Baruch Spinoza[^\n]+} },
        ],
        'AUTHOR',
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            '=head1 BUGS',
            { re =>
                  q/Please report any bugs.*C<bug-/
                . quotemeta($lc_dist_name)
                .  q/ at rt\.cpan\.org>.*changes\./
            },
        ],
        'BUGS',
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            '=head1 SUPPORT',
            { re => q/You can find documentation for this module.*/ },
            { re => q/\s+perldoc / . quotemeta($perl_name), },
            'You can also look for information at:',
            '=over 4',
        ],
        'Support 1',
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            { re => q/=item \* RT:[^\n]*/, },
            "L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=$dist_name>",
        ],
        'Support - RT',
    );


    # TEST:$cnt++
    $self->parse_paras(
        [
            { re => q/=item \* AnnoCPAN:[^\n]*/, },
            "L<http://annocpan.org/dist/$dist_name>",
        ],
        'AnnoCPAN',
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            { re => q/=item \* CPAN Ratings[^\n]*/, },
            "L<http://cpanratings.perl.org/d/$dist_name>",
        ],
        'CPAN Ratings',
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            { re => q/=item \* Search CPAN[^\n]*/, },
            "L<http://search.cpan.org/dist/$dist_name/>",
        ],
        'CPAN Ratings',
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            '=back',
        ],
        'Support - =back',
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            '=head1 ACKNOWLEDGEMENTS',
        ],
        'acknowledgements',
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            '=head1 COPYRIGHT & LICENSE',
            { re => q/Copyright \d+ Baruch Spinoza, all rights reserved\./ },
            ::chomp_me(<<'EOF'),
This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
EOF
        ],
        'copyright',
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            '=cut',
        ],
        '=cut POD end',
    );

    # TEST:$cnt++
    $self->consume(
        qq{1; # End of $perl_name},
        'End of module',
    );

    return;
}

# TEST:$parse_module_start_num_tests=$cnt;

package main;


{
    my $module_base_dir = File::Spec->catdir('t', 'data', 'MyModule-Test');

    Module::Starter->create_distro(
        distro  => 'MyModule-Test',
        modules => ['MyModule::Test', 'MyModule::Test::App'],
        dir     => $module_base_dir,
        builder => 'Module::Build',
        license => 'perl',
        author  => 'Baruch Spinoza',
        email   => 'spinoza@philosophers.tld',
        verbose => 0,
        force   => 0,
    );

    {
        my $readme = TestParseFile->new( {
            fn => File::Spec->catfile($module_base_dir, 'README'),
        });

        # TEST
        $readme->parse(qr{\AMyModule-Test\n\n}ms,
            'Starts with the package name',
        );

        # TEST
        $readme->parse(qr{\AThe README is used to introduce the module and provide instructions.*?\n\n}ms,
            'README used to introduce',
        );

        # TEST
        $readme->parse(
            qr{\AA README file is required for CPAN modules since CPAN extracts the.*?\n\n\n}ms,
            'A README file is required',
        );

        # TEST
        $readme->parse(qr{\A\n*INSTALLATION\n\nTo install this module, run the following commands:\n\n\s+\Qperl Build.PL\E\n\s+\Q./Build\E\n\s+\Q./Build test\E\n\s+\Q./Build install\E\n\n},
            'INSTALLATION section',
        );

        # TEST
        $readme->parse(qr{\ASUPPORT AND DOCUMENTATION\n\nAfter installing.*?^\s+perldoc MyModule::Test\n\n}ms,
            'Support and docs 1'
        );

        # TEST
        $readme->parse(qr{\AYou can also look for information at:\n\n\s+RT[^\n]+\n\s+\Qhttp://rt.cpan.org/NoAuth/Bugs.html?Dist=MyModule-Test\E\n\n}ms,
            'README - RT'
        );
    }

    {
        my $build_pl = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, "Build.PL"),
            }
        );

        # TEST
        $build_pl->parse(qr{\Ause strict;\nuse warnings;\nuse Module::Build;\n\n}ms,
            'Build.PL - Standard stuff at the beginning'
        );

        # TEST
        $build_pl->parse(qr{\A.*module_name *=> *'MyModule::Test',\n}ms,
            'Build.PL - module_name',
        );

        # TEST
        $build_pl->parse(qr{\A\s*license *=> *'perl',\n}ms,
            'Build.PL - license',
        );

        # TEST
        $build_pl->parse(qr{\A\s*dist_author *=> *\Q'Baruch Spinoza <spinoza\E\@\Qphilosophers.tld>',\E\n}ms,
            'Build.PL - dist_author',
        );

        # TEST
        $build_pl->parse(qr{\A\s*dist_version_from *=> *\Q'lib/MyModule/Test.pm',\E\n}ms,
            'Build.PL - dist_version_from',
        );

        # TEST
        $build_pl->parse(
            qr/\A\s*build_requires => \{\n *\Q'Test::More' => 0\E,\n\s*\},\n/ms,
            'Build.PL - Build Requires',
        );

        # TEST
        $build_pl->parse(
            qr/\A\s*add_to_cleanup *=> \Q[ 'MyModule-Test-*' ],\E\n/ms,
            'Build.PL - add_to_cleanup',
        );

        # TEST
        $build_pl->parse(
            qr/\A\s*create_makefile_pl *=> \Q'traditional',\E\n/ms,
            'Build.PL - create_makefile_pl',
        );

    }

    {
        my $manifest = TestParseFile->new( {
            fn => File::Spec->catfile($module_base_dir, 'MANIFEST'),
        } );

        # TEST
        $manifest->consume(<<'EOF', 'MANIFEST - Contents');
Build.PL
Changes
MANIFEST
README
lib/MyModule/Test.pm
lib/MyModule/Test/App.pm
t/00-load.t
t/pod-coverage.t
t/pod.t
EOF

        # TEST
        $manifest->is_end("MANIFEST - that's all folks!");
    }

    {
        my $pod_t = TestParseFile->new( {
            fn => File::Spec->catfile($module_base_dir, 't', 'pod.t'),
        } );

        my $minimal_test_pod = "1.22";
        # TEST
        $pod_t->consume(<<"EOF", 'pod.t - contents');
#!perl -T

use strict;
use warnings;
use Test::More;

# Ensure a recent version of Test::Pod
my \$min_tp = $minimal_test_pod;
eval "use Test::Pod \$min_tp";
plan skip_all => "Test::Pod \$min_tp required for testing POD" if \$\@;

all_pod_files_ok();
EOF

        # TEST
        $pod_t->is_end("pod.t - end.");
    }

    {
        my $pc_t = TestParseFile->new( {
            fn => File::Spec->catfile( $module_base_dir, 't', 'pod-coverage.t' )
        } );

        # TEST
        $pc_t->parse(
            qr/\Ause strict;\nuse warnings;\nuse Test::More;\n\n/ms,
            'pod-coverage.t - header',
        );

        my $l1 = q{eval "use Test::Pod::Coverage $min_tpc";};

        # TEST
        $pc_t->parse(
            qr/\A# Ensure a recent[^\n]+\nmy \$min_tpc = \d+\.\d+;\n\Q$l1\E\nplan skip_all[^\n]+\n *if \$\@;\n\n/ms,
            'pod-coverage.t - min_tpc block',
        );

        $l1 = q{eval "use Pod::Coverage $min_pc";};
        my $s1 = q{# Test::Pod::Coverage doesn't require a minimum };

        # TEST
        $pc_t->parse(
            qr/\A\Q$s1\E[^\n]+\n# [^\n]+\nmy \$min_pc = \d+\.\d+;\n\Q$l1\E\nplan skip_all[^\n]+\n *if \$\@;\n\n/ms,
            'pod-coverage.t - min_pod_coverage block',
        );

        # TEST
        $pc_t->parse(
            qr/all_pod_coverage_ok\(\);\n/,
            'pod-coverage.t - all_pod_coverage_ok',
        );

        # TEST
        $pc_t->is_end(
            'pod-coverage.t - EOF',
        );
    }

    {
        my $mod1 = TestParseModuleFile->new( {
            fn        => File::Spec->catfile( $module_base_dir, qw(lib MyModule Test.pm) ),
            perl_name => 'MyModule::Test',
            dist_name => 'MyModule-Test',
        } );

        # TEST*$parse_module_start_num_tests
        $mod1->parse_module_start();

    }

    {
        my $mod2 = TestParseModuleFile->new( {
            fn        => File::Spec->catfile( $module_base_dir, qw(lib MyModule Test App.pm) ),
            perl_name => 'MyModule::Test::App',
            dist_name => 'MyModule-Test',
        } );

        # TEST*$parse_module_start_num_tests
        $mod2->parse_module_start();

    }

    my $files_list;
    if (!$ENV{'DONT_DEL'}) {
        rmtree ($module_base_dir, {result => \$files_list});
    }
}

=head1 NAME

t/test-dist.t - test the integrity of prepared distributions.

=head1 AUTHOR

Shlomi Fish, L<http://www.shlomifish.org/>

