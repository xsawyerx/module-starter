#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 545;

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

    if (@_) {
        $self->{_filename} = shift;
    }

    return $self->{_filename};
}

sub _text {
    my $self = shift;

    if (@_) {
        $self->{_text} = shift;
    }

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
        or Carp::confess( "Cannot open $filename" );
    $text = <$in>;
    close($in);

    return \$text;
}

sub parse {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ($self, $re, $msg) = @_;

    my $verdict = ok (scalar(${$self->_text()} =~ s{$re}{}ms), $self->format_msg($msg));

    if (!$verdict ) {
        diag('Filename == ' . $self->_filename());
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
        diag('Filename == ' . $self->_filename());
    }

    return $verdict;
}

sub is_end {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ($self, $msg) = @_;

    my $verdict = is (${$self->_text()}, "", $self->format_msg($msg));

    if (!$verdict ) {
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

    return $self->parse( $regex, $msg );
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

    if (@_) {
        $self->{_perl_name} = shift;
    }

    return $self->{_perl_name};
}

sub _dist_name {
    my $self = shift;

    if (@_) {
        $self->{_dist_name} = shift;
    }

    return $self->{_dist_name};
}

sub _author_name {
    my $self = shift;

    if (@_) {
        $self->{_author_name} = shift;
    }

    return $self->{_author_name};
}

sub _license {
    my $self = shift;

    if (@_) {
        $self->{_license} = shift;
    }

    return $self->{_license};
}

sub _init {
    my ($self, $args) = @_;

    $self->SUPER::_init($args);

    $self->_perl_name($args->{perl_name});

    $self->_dist_name($args->{dist_name});

    $self->_author_name($args->{author_name});

    $self->_license($args->{license});

    return;
}

sub format_msg {
    my ($self, $msg) = @_;

    return $self->_perl_name() . " - $msg";
}

sub _get_license_blurb {
    my $self = shift;

    my $texts =
    {
        'perl' =>
            [::chomp_me(<<'EOF')],
This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
EOF

        'mit' =>
        [
            ::chomp_me(<<'EOF'),
This program is distributed under the MIT (X11) License:
L<http://www.opensource.org/licenses/mit-license.php>
EOF
            ::chomp_me(<<'EOF'),
Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:
EOF
            ::chomp_me(<<'EOF'),
The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.
EOF
            ::chomp_me(<<'EOF'),
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
EOF
        ],
        'bsd' =>
        [
            split(/\n\n+/, <<"EOF")
This program is distributed under the (Revised) BSD License:
L<http://www.opensource.org/licenses/bsd-license.php>

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

* Neither the name of @{[$self->_author_name()]}'s Organization
nor the names of its contributors may be used to endorse or promote
products derived from this software without specific prior written
permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
EOF
        ],
        'gpl' =>
        [
            split(/\n\n+/, <<"EOF")
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 2 dated June, 1991 or at your option
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

A copy of the GNU General Public License is available in the source tree;
if not, write to the Free Software Foundation, Inc.,
59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
EOF
        ],
        'lgpl' =>
        [
            split(/\n\n+/, <<"EOF")
This program is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this program; if not, write to the Free
Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
02111-1307 USA.
EOF
        ],
        'apache' =>
        [
            split(/\n\n+/, <<"EOF")
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    L<http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
EOF
        ],
    };

    return @{$texts->{$self->_license()}};
}

# TEST:$cnt=0;
sub parse_module_start {
    my $self = shift;

    my $perl_name = $self->_perl_name();
    my $dist_name = $self->_dist_name();
    my $author_name = $self->_author_name();
    my $lc_dist_name = lc($dist_name);

    # TEST:$cnt++;
    $self->parse(
        qr/\Apackage \Q$perl_name\E;\n\nuse 5.006;\nuse strict;\nuse warnings;\n\n/ms,
        'start',
    );

    {
        my $s1 = qq{$perl_name - The great new $perl_name!};

        # TEST:$cnt++;
        $self->parse(
            qr/\A=head1 NAME\n\n\Q$s1\E\n\n/ms,
            "NAME Pod.",
        );
    }

    # TEST:$cnt++;
    $self->parse(
        qr/\A=head1 VERSION\n\nVersion 0\.01\n\n=cut\n\nour \$VERSION = '0\.01';\n+/,
        "module version",
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
                . q{\n\s*} . quotemeta('...'),
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
        "EXPORT",
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            "=head1 SUBROUTINES/METHODS",
            "=head2 function1",
            "=cut",
            "sub function1 {\n}",
        ],
        "function1",
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            "=head2 function2",
            "=cut",
            "sub function2 {\n}",
        ],
        "function2",
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            "=head1 AUTHOR",
            { re => quotemeta($author_name) . q{[^\n]+} },
        ],
        "AUTHOR",
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            "=head1 BUGS",
            { re =>
                  q/Please report any bugs.*C<bug-/
                . quotemeta($lc_dist_name)
                .  q/ at rt\.cpan\.org>.*changes\./
            },
        ],
        "BUGS",
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            "=head1 SUPPORT",
            { re => q/You can find documentation for this module.*/ },
            { re => q/\s+perldoc / . quotemeta($perl_name), },
            "You can also look for information at:",
            "=over 4",
        ],
        "Support 1",
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            { re => q/=item \* RT:[^\n]*/, },
            "L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=$dist_name>",
        ],
        "Support - RT",
    );


    # TEST:$cnt++
    $self->parse_paras(
        [
            { re => q/=item \* AnnoCPAN:[^\n]*/, },
            "L<http://annocpan.org/dist/$dist_name>",
        ],
        "AnnoCPAN",
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            { re => q/=item \* CPAN Ratings[^\n]*/, },
            "L<http://cpanratings.perl.org/d/$dist_name>",
        ],
        "CPAN Ratings",
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            { re => q/=item \* Search CPAN[^\n]*/, },
            "L<http://search.cpan.org/dist/$dist_name/>",
        ],
        "CPAN Ratings",
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            "=back",
        ],
        "Support - =back",
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            "=head1 ACKNOWLEDGEMENTS",
        ],
        "acknowledgements",
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            "=head1 LICENSE AND COPYRIGHT",
            { re =>
                  q/Copyright \d+ /
                . quotemeta($author_name)
                . q/\./
            },
            $self->_get_license_blurb(),
        ],
        "copyright",
    );

    # TEST:$cnt++
    $self->parse_paras(
        [
            "=cut",
        ],
        "=cut POD end",
    );

    # TEST:$cnt++
    $self->consume(
        qq{1; # End of $perl_name},
        "End of module",
    );

    return;
}

# TEST:$parse_module_start_num_tests=$cnt;

package main;

{
    my $module_base_dir =
        File::Spec->catdir("t", "data", "MyModule-Test")
        ;

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
        my $readme = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, "README"),
            }
        );

        # TEST
        $readme->parse(qr{\AMyModule-Test\n\n}ms,
            "Starts with the package name",
        );

        # TEST
        $readme->parse(qr{\AThe README is used to introduce the module and provide instructions.*?\n\n}ms,
            "README used to introduce",
        );

        # TEST
        $readme->parse(
            qr{\AA README file is required for CPAN modules since CPAN extracts the.*?\n\n\n}ms,
            "A README file is required",
        );

        # TEST
        $readme->parse(qr{\A\n*INSTALLATION\n\nTo install this module, run the following commands:\n\n\s+\Qperl Build.PL\E\n\s+\Q./Build\E\n\s+\Q./Build test\E\n\s+\Q./Build install\E\n\n},
            "INSTALLATION section",
        );

        # TEST
        $readme->parse(qr{\ASUPPORT AND DOCUMENTATION\n\nAfter installing.*?^\s+perldoc MyModule::Test\n\n}ms,
            "Support and docs 1"
        );

        # TEST
        $readme->parse(qr{\AYou can also look for information at:\n\n\s+RT[^\n]+\n\s+\Qhttp://rt.cpan.org/NoAuth/Bugs.html?Dist=MyModule-Test\E\n\n}ms,
            "README - RT"
        );
    }

    {
        my $build_pl = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, "Build.PL"),
            }
        );

        # TEST
        $build_pl->parse(qr{\Ause 5.006;\nuse strict;\nuse warnings;\nuse Module::Build;\n\n}ms,
            "Build.PL - Standard stuff at the beginning"
        );

        # TEST
        $build_pl->parse(qr{\A.*module_name *=> *'MyModule::Test',\n}ms,
            "Build.PL - module_name",
        );

        # TEST
        $build_pl->parse(qr{\A\s*license *=> *'perl',\n}ms,
            "Build.PL - license",
        );

        # TEST
        $build_pl->parse(qr{\A\s*dist_author *=> *\Qq{Baruch Spinoza <spinoza\E\@\Qphilosophers.tld>},\E\n}ms,
            "Build.PL - dist_author",
        );

        # TEST
        $build_pl->parse(qr{\A\s*dist_version_from *=> *\Q'lib/MyModule/Test.pm',\E\n}ms,
            "Build.PL - dist_version_from",
        );

        # TEST
        $build_pl->parse(
            qr/\A\s*build_requires => \{\n *\Q'Test::More' => 0\E,\n\s*\},\n/ms,
            "Build.PL - Build Requires",
        );

        # TEST
        $build_pl->parse(
            qr/\A\s*requires => \{\n *\Q'perl' => 5.006\E,\n\s*\},\n/ms,
            "Build.PL - Build Requires",
        );

        # TEST
        $build_pl->parse(
            qr/\A\s*add_to_cleanup *=> \Q[ 'MyModule-Test-*' ],\E\n/ms,
            "Build.PL - add_to_cleanup",
        );

        # TEST
        $build_pl->parse(
            qr/\A\s*create_makefile_pl *=> \Q'traditional',\E\n/ms,
            "Build.PL - create_makefile_pl",
        );

    }

    {
        my $manifest = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, 'MANIFEST'),
            }
        );

        # TEST
        $manifest->consume(<<"EOF", 'MANIFEST - Contents');
Build.PL
Changes
lib/MyModule/Test.pm
lib/MyModule/Test/App.pm
MANIFEST\t\t\tThis list of files
README
t/00-load.t
t/manifest.t
t/pod-coverage.t
t/pod.t
EOF

        # TEST
        $manifest->is_end("MANIFEST - that's all folks!");
    }

    {
        my $manifest_t = TestParseFile->new( {
            fn => File::Spec->catfile( $module_base_dir, 't', 'manifest.t' )
        } );

        my $minimal_test_checkmanifest = '0.9';
        $manifest_t->consume( <<"EOF", 'manifest.t - contents' );
#!perl -T

use strict;
use warnings;
use Test::More;

unless ( \$ENV{RELEASE_TESTING} ) {
    plan( skip_all => "Author tests not required for installation" );
}

eval "use Test::CheckManifest $minimal_test_checkmanifest";
plan skip_all => "Test::CheckManifest 0.9 required" if \$\@;
ok_manifest();
EOF

        # TEST
        $manifest_t->is_end('manifest.t - end.');
    }

    {
        my $pod_t = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, 't', 'pod.t'),
            }
        );

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
        $pod_t->is_end('pod.t - end.');
    }

    {
        my $pc_t = TestParseFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, 't', 'pod-coverage.t'
                ),
            }
        );

        # TEST
        $pc_t->parse(
            qr/\Ause strict;\nuse warnings;\nuse Test::More;\n\n/ms,
            "pod-coverage.t - header",
        );

        my $l1 = q{eval "use Test::Pod::Coverage $min_tpc";};

        # TEST
        $pc_t->parse(
            qr/\A# Ensure a recent[^\n]+\nmy \$min_tpc = \d+\.\d+;\n\Q$l1\E\nplan skip_all[^\n]+\n *if \$\@;\n\n/ms,
            "pod-coverage.t - min_tpc block",
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
        my $mod1 = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib MyModule Test.pm),
                ),
                perl_name   => 'MyModule::Test',
                dist_name   => 'MyModule-Test',
                author_name => 'Baruch Spinoza',
                license => 'perl',
            }
        );

        # TEST*$parse_module_start_num_tests
        $mod1->parse_module_start();

    }

    {
        my $mod2 = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib MyModule Test App.pm),
                ),
                perl_name   => 'MyModule::Test::App',
                dist_name   => 'MyModule-Test',
                author_name => 'Baruch Spinoza',
                license => 'perl',
            }
        );

        # TEST*$parse_module_start_num_tests
        $mod2->parse_module_start();

    }

    my $files_list;
    if (!$ENV{"DONT_DEL"})
    {
        rmtree ($module_base_dir, {result => \$files_list});
    }
}

{
    my $module_base_dir =
        File::Spec->catdir('t', 'data', 'Book-Park-Mansfield')
        ;

    Module::Starter->create_distro(
        distro  => 'Book-Park-Mansfield',
        modules => [
            'Book::Park::Mansfield',
            'Book::Park::Mansfield::Base',
            'Book::Park::Mansfield::FannyPrice',
            'JAUSTEN::Utils',
        ],
        dir     => $module_base_dir,
        builder => 'Module::Build',
        license => 'perl',
        author  => 'Jane Austen',
        email   => 'jane.austen@writers.tld',
        verbose => 0,
        force   => 0,
    );

    {
        my $readme = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, "README"),
            }
        );

        # TEST
        $readme->parse(qr{\ABook-Park-Mansfield\n\n}ms,
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
        $readme->parse(qr{\ASUPPORT AND DOCUMENTATION\n\nAfter installing.*?^\s+perldoc Book::Park::Mansfield\n\n}ms,
            'Support and docs 1'
        );

        # TEST
        $readme->parse(qr{\AYou can also look for information at:\n\n\s+RT[^\n]+\n\s+\Qhttp://rt.cpan.org/NoAuth/Bugs.html?Dist=Book-Park-Mansfield\E\n\n}ms,
            'README - RT'
        );
    }

    {
        my $mod1 = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib Book Park Mansfield.pm),
                ),
                perl_name   => 'Book::Park::Mansfield',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'perl',
            }
        );

        # TEST*$parse_module_start_num_tests
        $mod1->parse_module_start();

    }

    {
        my $jausten_mod = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib JAUSTEN Utils.pm),
                ),
                perl_name   => 'JAUSTEN::Utils',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'perl',
            }
        );

        # TEST*$parse_module_start_num_tests
        $jausten_mod->parse_module_start();
    }

    {
        my $mod2 = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib Book Park Mansfield Base.pm),
                ),
                perl_name   => 'Book::Park::Mansfield::Base',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'perl',
            }
        );

        # TEST*$parse_module_start_num_tests
        $mod2->parse_module_start();

    }

    my $files_list;
    if (!$ENV{'DONT_DEL_JANE'})
    {
        rmtree ($module_base_dir, {result => \$files_list});
    }
}

{
    my $module_base_dir =
        File::Spec->catdir("t", "data", "second-Book-Park-Mansfield")
        ;

    Module::Starter->create_distro(
        distro  => 'Book-Park-Mansfield',
        modules => [
            'Book::Park::Mansfield',
            'Book::Park::Mansfield::Base',
            'Book::Park::Mansfield::FannyPrice',
            'JAUSTEN::Utils',
        ],
        dir     => $module_base_dir,
        builder => 'ExtUtils::MakeMaker',
        license => 'perl',
        author  => 'Jane Austen',
        email   => 'jane.austen@writers.tld',
        verbose => 0,
        force   => 0,
    );

    {
        my $readme = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, "README"),
            }
        );

        # TEST
        $readme->parse(qr{\ABook-Park-Mansfield\n\n}ms,
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
        $readme->parse(qr{\A\n*INSTALLATION\n\nTo install this module, run the following commands:\n\n\s+\Qperl Makefile.PL\E\n\s+\Qmake\E\n\s+\Qmake test\E\n\s+\Qmake install\E\n\n},
            'INSTALLATION section',
        );

        # TEST
        $readme->parse(qr{\ASUPPORT AND DOCUMENTATION\n\nAfter installing.*?^\s+perldoc Book::Park::Mansfield\n\n}ms,
            'Support and docs 1'
        );

        # TEST
        $readme->parse(qr{\AYou can also look for information at:\n\n\s+RT[^\n]+\n\s+\Qhttp://rt.cpan.org/NoAuth/Bugs.html?Dist=Book-Park-Mansfield\E\n\n}ms,
            'README - RT'
        );
    }

    {
        my $makefile_pl = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, "Makefile.PL"),
            }
        );

        # TEST
        $makefile_pl->parse(qr{\Ause 5.006;\nuse strict;\nuse warnings;\nuse ExtUtils::MakeMaker;\n\n}ms,
            "Makefile.PL - Standard stuff at the beginning"
        );

        # TEST
        $makefile_pl->parse(qr{\A.*NAME *=> *'Book::Park::Mansfield',\n}ms,
            "Makefile.PL - NAME",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*AUTHOR *=> *\Qq{Jane Austen <jane.austen\E\@\Qwriters.tld>},\E\n}ms,
            "Makefile.PL - AUTHOR",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*VERSION_FROM *=> *\Q'lib/Book/Park/Mansfield.pm',\E\n}ms,
            "Makefile.PL - VERSION_FROM",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*ABSTRACT_FROM *=> *\Q'lib/Book/Park/Mansfield.pm',\E\n}ms,
            "Makefile.PL - ABSTRACT_FROM",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*\(\$ExtUtils::MakeMaker::VERSION \>= \d+\.\d+\n\s*\? \(\s*'LICENSE'\s*=>\s*'perl'\s*\)\n\s*:\s*\(\s*\)\)\s*,\n}ms,
            "Makefile.PL - LICENSE",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*PL_FILES *=> *\{\},\n}ms,
            "Makefile.PL - PL_FILES",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*PREREQ_PM *=> *\{\n\s*'Test::More' *=> *0,\n\s*\},\n}ms,
            "Makefile.PL - PREREQ_PM",
        );

    }

    {
        my $manifest = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, 'MANIFEST'),
            }
        );

        my $contents = <<"EOF";
Changes
lib/Book/Park/Mansfield.pm
lib/Book/Park/Mansfield/Base.pm
lib/Book/Park/Mansfield/FannyPrice.pm
lib/JAUSTEN/Utils.pm
Makefile.PL
MANIFEST\t\t\tThis list of files
README
t/00-load.t
t/manifest.t
t/pod-coverage.t
t/pod.t
EOF

        # TEST
        $manifest->consume(
            $contents,
            "MANIFEST for Makefile.PL'ed Module",
        );

        # TEST
        $manifest->is_end("MANIFEST - that's all folks!");
    }

    {
        my $mod1 = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib Book Park Mansfield.pm),
                ),
                perl_name   => 'Book::Park::Mansfield',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'perl',
            }
        );

        # TEST*$parse_module_start_num_tests
        $mod1->parse_module_start();

    }

    {
        my $jausten_mod = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib JAUSTEN Utils.pm),
                ),
                perl_name   => 'JAUSTEN::Utils',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'perl',
            }
        );

        # TEST*$parse_module_start_num_tests
        $jausten_mod->parse_module_start();
    }

    {
        my $mod2 = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib Book Park Mansfield Base.pm),
                ),
                perl_name   => 'Book::Park::Mansfield::Base',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'perl',
            }
        );

        # TEST*$parse_module_start_num_tests
        $mod2->parse_module_start();

    }

    my $files_list;
    if (!$ENV{'DONT_DEL_JANE2'}) {
        rmtree ($module_base_dir, {result => \$files_list});
    }
}

{
    my $module_base_dir =
        File::Spec->catdir("t", "data", "x11l-Book-Park-Mansfield")
        ;

    Module::Starter->create_distro(
        distro  => 'Book-Park-Mansfield',
        modules => [
            'Book::Park::Mansfield',
            'Book::Park::Mansfield::Base',
            'Book::Park::Mansfield::FannyPrice',
            'JAUSTEN::Utils',
        ],
        dir     => $module_base_dir,
        builder => 'ExtUtils::MakeMaker',
        license => 'mit',
        author  => 'Jane Austen',
        email   => 'jane.austen@writers.tld',
        verbose => 0,
        force   => 0,
    );

    {
        my $readme = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, "README"),
            }
        );

        # TEST
        $readme->parse(qr{\ABook-Park-Mansfield\n\n}ms,
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
        $readme->parse(qr{\A\n*INSTALLATION\n\nTo install this module, run the following commands:\n\n\s+\Qperl Makefile.PL\E\n\s+\Qmake\E\n\s+\Qmake test\E\n\s+\Qmake install\E\n\n},
            'INSTALLATION section',
        );

        # TEST
        $readme->parse(qr{\ASUPPORT AND DOCUMENTATION\n\nAfter installing.*?^\s+perldoc Book::Park::Mansfield\n\n}ms,
            'Support and docs 1'
        );

        # TEST
        $readme->parse(qr{\AYou can also look for information at:\n\n\s+RT[^\n]+\n\s+\Qhttp://rt.cpan.org/NoAuth/Bugs.html?Dist=Book-Park-Mansfield\E\n\n}ms,
            'README - RT'
        );
    }

    {
        my $makefile_pl = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, "Makefile.PL"),
            }
        );

        # TEST
        $makefile_pl->parse(qr{\Ause 5.006;\nuse strict;\nuse warnings;\nuse ExtUtils::MakeMaker;\n\n}ms,
            "Makefile.PL - Standard stuff at the beginning"
        );

        # TEST
        $makefile_pl->parse(qr{\A.*NAME *=> *'Book::Park::Mansfield',\n}ms,
            "Makefile.PL - NAME",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*AUTHOR *=> *\Qq{Jane Austen <jane.austen\E\@\Qwriters.tld>},\E\n}ms,
            "Makefile.PL - AUTHOR",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*VERSION_FROM *=> *\Q'lib/Book/Park/Mansfield.pm',\E\n}ms,
            "Makefile.PL - VERSION_FROM",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*ABSTRACT_FROM *=> *\Q'lib/Book/Park/Mansfield.pm',\E\n}ms,
            "Makefile.PL - ABSTRACT_FROM",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*\(\$ExtUtils::MakeMaker::VERSION \>= \d+\.\d+\n\s*\? \(\s*'LICENSE'\s*=>\s*'mit'\s*\)\n\s*:\s*\(\s*\)\)\s*,\n}ms,
            "Makefile.PL - LICENSE",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*PL_FILES *=> *\{\},\n}ms,
            "Makefile.PL - PL_FILES",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*PREREQ_PM *=> *\{\n\s*'Test::More' *=> *0,\n\s*\},\n}ms,
            "Makefile.PL - PREREQ_PM",
        );

    }

    {
        my $manifest = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, 'MANIFEST'),
            }
        );

        my $contents = <<"EOF";
Changes
lib/Book/Park/Mansfield.pm
lib/Book/Park/Mansfield/Base.pm
lib/Book/Park/Mansfield/FannyPrice.pm
lib/JAUSTEN/Utils.pm
Makefile.PL
MANIFEST\t\t\tThis list of files
README
t/00-load.t
t/manifest.t
t/pod-coverage.t
t/pod.t
EOF

        # TEST
        $manifest->consume(
            $contents,
            "MANIFEST for Makefile.PL'ed Module",
        );

        # TEST
        $manifest->is_end("MANIFEST - that's all folks!");
    }

    {
        my $mod1 = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib Book Park Mansfield.pm),
                ),
                perl_name   => 'Book::Park::Mansfield',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'mit',
            }
        );

        # TEST*$parse_module_start_num_tests
        $mod1->parse_module_start();

    }

    {
        my $jausten_mod = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib JAUSTEN Utils.pm),
                ),
                perl_name   => 'JAUSTEN::Utils',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'mit',
            }
        );

        # TEST*$parse_module_start_num_tests
        $jausten_mod->parse_module_start();
    }

    {
        my $mod2 = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib Book Park Mansfield Base.pm),
                ),
                perl_name   => 'Book::Park::Mansfield::Base',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'mit',
            }
        );

        # TEST*$parse_module_start_num_tests
        $mod2->parse_module_start();

    }

    my $files_list;
    if (!$ENV{'DONT_DEL_X11L'}) {
        rmtree ($module_base_dir, {result => \$files_list});
    }
}

{
    my $module_base_dir =
        File::Spec->catdir("t", "data", "bsdl-Book-Park-Mansfield")
        ;

    Module::Starter->create_distro(
        distro  => 'Book-Park-Mansfield',
        modules => [
            'Book::Park::Mansfield',
            'Book::Park::Mansfield::Base',
            'Book::Park::Mansfield::FannyPrice',
            'JAUSTEN::Utils',
        ],
        dir     => $module_base_dir,
        builder => 'ExtUtils::MakeMaker',
        license => 'bsd',
        author  => 'Jane Austen',
        email   => 'jane.austen@writers.tld',
        verbose => 0,
        force   => 0,
    );

    {
        my $readme = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, "README"),
            }
        );

        # TEST
        $readme->parse(qr{\ABook-Park-Mansfield\n\n}ms,
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
        $readme->parse(qr{\A\n*INSTALLATION\n\nTo install this module, run the following commands:\n\n\s+\Qperl Makefile.PL\E\n\s+\Qmake\E\n\s+\Qmake test\E\n\s+\Qmake install\E\n\n},
            'INSTALLATION section',
        );

        # TEST
        $readme->parse(qr{\ASUPPORT AND DOCUMENTATION\n\nAfter installing.*?^\s+perldoc Book::Park::Mansfield\n\n}ms,
            'Support and docs 1'
        );

        # TEST
        $readme->parse(qr{\AYou can also look for information at:\n\n\s+RT[^\n]+\n\s+\Qhttp://rt.cpan.org/NoAuth/Bugs.html?Dist=Book-Park-Mansfield\E\n\n}ms,
            'README - RT'
        );
    }

    {
        my $makefile_pl = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, "Makefile.PL"),
            }
        );

        # TEST
        $makefile_pl->parse(qr{\Ause 5.006;\nuse strict;\nuse warnings;\nuse ExtUtils::MakeMaker;\n\n}ms,
            "Makefile.PL - Standard stuff at the beginning"
        );

        # TEST
        $makefile_pl->parse(qr{\A.*NAME *=> *'Book::Park::Mansfield',\n}ms,
            "Makefile.PL - NAME",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*AUTHOR *=> *\Qq{Jane Austen <jane.austen\E\@\Qwriters.tld>},\E\n}ms,
            "Makefile.PL - AUTHOR",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*VERSION_FROM *=> *\Q'lib/Book/Park/Mansfield.pm',\E\n}ms,
            "Makefile.PL - VERSION_FROM",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*ABSTRACT_FROM *=> *\Q'lib/Book/Park/Mansfield.pm',\E\n}ms,
            "Makefile.PL - ABSTRACT_FROM",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*\(\$ExtUtils::MakeMaker::VERSION \>= \d+\.\d+\n\s*\? \(\s*'LICENSE'\s*=>\s*'bsd'\s*\)\n\s*:\s*\(\s*\)\)\s*,\n}ms,
            "Makefile.PL - LICENSE",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*PL_FILES *=> *\{\},\n}ms,
            "Makefile.PL - PL_FILES",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*PREREQ_PM *=> *\{\n\s*'Test::More' *=> *0,\n\s*\},\n}ms,
            "Makefile.PL - PREREQ_PM",
        );

    }

    {
        my $manifest = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, 'MANIFEST'),
            }
        );

        my $contents = <<"EOF";
Changes
lib/Book/Park/Mansfield.pm
lib/Book/Park/Mansfield/Base.pm
lib/Book/Park/Mansfield/FannyPrice.pm
lib/JAUSTEN/Utils.pm
Makefile.PL
MANIFEST\t\t\tThis list of files
README
t/00-load.t
t/manifest.t
t/pod-coverage.t
t/pod.t
EOF

        # TEST
        $manifest->consume(
            $contents,
            "MANIFEST for Makefile.PL'ed Module",
        );

        # TEST
        $manifest->is_end("MANIFEST - that's all folks!");
    }

    {
        my $mod1 = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib Book Park Mansfield.pm),
                ),
                perl_name   => 'Book::Park::Mansfield',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'bsd',
            }
        );

        # TEST*$parse_module_start_num_tests
        $mod1->parse_module_start();

    }

    {
        my $jausten_mod = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib JAUSTEN Utils.pm),
                ),
                perl_name   => 'JAUSTEN::Utils',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'bsd',
            }
        );

        # TEST*$parse_module_start_num_tests
        $jausten_mod->parse_module_start();
    }

    {
        my $mod2 = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib Book Park Mansfield Base.pm),
                ),
                perl_name   => 'Book::Park::Mansfield::Base',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'bsd',
            }
        );

        # TEST*$parse_module_start_num_tests
        $mod2->parse_module_start();

    }

    my $files_list;
    if (!$ENV{'DONT_DEL_BSDL'}) {
        rmtree ($module_base_dir, {result => \$files_list});
    }
}

{
    my $module_base_dir =
        File::Spec->catdir('t', 'data', 'gpl-Book-Park-Mansfield')
        ;

    Module::Starter->create_distro(
        distro  => 'Book-Park-Mansfield',
        modules => [
            'Book::Park::Mansfield',
            'Book::Park::Mansfield::Base',
            'Book::Park::Mansfield::FannyPrice',
            'JAUSTEN::Utils',
        ],
        dir     => $module_base_dir,
        builder => 'Module::Build',
        license => 'gpl',
        author  => 'Jane Austen',
        email   => 'jane.austen@writers.tld',
        verbose => 0,
        force   => 0,
    );

    {
        my $readme = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, "README"),
            }
        );

        # TEST
        $readme->parse(qr{\ABook-Park-Mansfield\n\n}ms,
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
        $readme->parse(qr{\ASUPPORT AND DOCUMENTATION\n\nAfter installing.*?^\s+perldoc Book::Park::Mansfield\n\n}ms,
            'Support and docs 1'
        );

        # TEST
        $readme->parse(qr{\AYou can also look for information at:\n\n\s+RT[^\n]+\n\s+\Qhttp://rt.cpan.org/NoAuth/Bugs.html?Dist=Book-Park-Mansfield\E\n\n}ms,
            'README - RT'
        );
    }

    {
        my $mod1 = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib Book Park Mansfield.pm),
                ),
                perl_name   => 'Book::Park::Mansfield',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'gpl',
            }
        );

        # TEST*$parse_module_start_num_tests
        $mod1->parse_module_start();

    }

    {
        my $jausten_mod = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib JAUSTEN Utils.pm),
                ),
                perl_name   => 'JAUSTEN::Utils',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'gpl',
            }
        );

        # TEST*$parse_module_start_num_tests
        $jausten_mod->parse_module_start();
    }

    {
        my $mod2 = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib Book Park Mansfield Base.pm),
                ),
                perl_name   => 'Book::Park::Mansfield::Base',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'gpl',
            }
        );

        # TEST*$parse_module_start_num_tests
        $mod2->parse_module_start();

    }

    my $files_list;
    if (!$ENV{'DONT_DEL_GPL'})
    {
        rmtree ($module_base_dir, {result => \$files_list});
    }
}

{
    my $module_base_dir =
        File::Spec->catdir('t', 'data', 'lgpl-Book-Park-Mansfield')
        ;

    Module::Starter->create_distro(
        distro  => 'Book-Park-Mansfield',
        modules => [
            'Book::Park::Mansfield',
            'Book::Park::Mansfield::Base',
            'Book::Park::Mansfield::FannyPrice',
            'JAUSTEN::Utils',
        ],
        dir     => $module_base_dir,
        builder => 'Module::Build',
        license => 'lgpl',
        author  => 'Jane Austen',
        email   => 'jane.austen@writers.tld',
        verbose => 0,
        force   => 0,
    );

    {
        my $readme = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, "README"),
            }
        );

        # TEST
        $readme->parse(qr{\ABook-Park-Mansfield\n\n}ms,
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
        $readme->parse(qr{\ASUPPORT AND DOCUMENTATION\n\nAfter installing.*?^\s+perldoc Book::Park::Mansfield\n\n}ms,
            'Support and docs 1'
        );

        # TEST
        $readme->parse(qr{\AYou can also look for information at:\n\n\s+RT[^\n]+\n\s+\Qhttp://rt.cpan.org/NoAuth/Bugs.html?Dist=Book-Park-Mansfield\E\n\n}ms,
            'README - RT'
        );
    }

    {
        my $mod1 = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib Book Park Mansfield.pm),
                ),
                perl_name   => 'Book::Park::Mansfield',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'lgpl',
            }
        );

        # TEST*$parse_module_start_num_tests
        $mod1->parse_module_start();

    }

    {
        my $jausten_mod = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib JAUSTEN Utils.pm),
                ),
                perl_name   => 'JAUSTEN::Utils',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'lgpl',
            }
        );

        # TEST*$parse_module_start_num_tests
        $jausten_mod->parse_module_start();
    }

    {
        my $mod2 = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib Book Park Mansfield Base.pm),
                ),
                perl_name   => 'Book::Park::Mansfield::Base',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'lgpl',
            }
        );

        # TEST*$parse_module_start_num_tests
        $mod2->parse_module_start();

    }

    my $files_list;
    if (!$ENV{'DONT_DEL_LGPL'})
    {
        rmtree ($module_base_dir, {result => \$files_list});
    }
}

{
    my $module_base_dir =
        File::Spec->catdir("t", "data", "apache-Book-Park-Mansfield")
        ;

    Module::Starter->create_distro(
        distro  => 'Book-Park-Mansfield',
        modules => [
            'Book::Park::Mansfield',
            'Book::Park::Mansfield::Base',
            'Book::Park::Mansfield::FannyPrice',
            'JAUSTEN::Utils',
        ],
        dir     => $module_base_dir,
        builder => 'ExtUtils::MakeMaker',
        license => 'apache',
        author  => 'Jane Austen',
        email   => 'jane.austen@writers.tld',
        verbose => 0,
        force   => 0,
    );

    {
        my $readme = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, "README"),
            }
        );

        # TEST
        $readme->parse(qr{\ABook-Park-Mansfield\n\n}ms,
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
        $readme->parse(qr{\A\n*INSTALLATION\n\nTo install this module, run the following commands:\n\n\s+\Qperl Makefile.PL\E\n\s+\Qmake\E\n\s+\Qmake test\E\n\s+\Qmake install\E\n\n},
            'INSTALLATION section',
        );

        # TEST
        $readme->parse(qr{\ASUPPORT AND DOCUMENTATION\n\nAfter installing.*?^\s+perldoc Book::Park::Mansfield\n\n}ms,
            'Support and docs 1'
        );

        # TEST
        $readme->parse(qr{\AYou can also look for information at:\n\n\s+RT[^\n]+\n\s+\Qhttp://rt.cpan.org/NoAuth/Bugs.html?Dist=Book-Park-Mansfield\E\n\n}ms,
            'README - RT'
        );
    }

    {
        my $makefile_pl = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, "Makefile.PL"),
            }
        );

        # TEST
        $makefile_pl->parse(qr{\Ause 5.006;\nuse strict;\nuse warnings;\nuse ExtUtils::MakeMaker;\n\n}ms,
            "Makefile.PL - Standard stuff at the beginning"
        );

        # TEST
        $makefile_pl->parse(qr{\A.*NAME *=> *'Book::Park::Mansfield',\n}ms,
            "Makefile.PL - NAME",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*AUTHOR *=> *\Qq{Jane Austen <jane.austen\E\@\Qwriters.tld>},\E\n}ms,
            "Makefile.PL - AUTHOR",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*VERSION_FROM *=> *\Q'lib/Book/Park/Mansfield.pm',\E\n}ms,
            "Makefile.PL - VERSION_FROM",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*ABSTRACT_FROM *=> *\Q'lib/Book/Park/Mansfield.pm',\E\n}ms,
            "Makefile.PL - ABSTRACT_FROM",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*\(\$ExtUtils::MakeMaker::VERSION \>= \d+\.\d+\n\s*\? \(\s*'LICENSE'\s*=>\s*'apache'\s*\)\n\s*:\s*\(\s*\)\)\s*,\n}ms,
            "Makefile.PL - LICENSE",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*PL_FILES *=> *\{\},\n}ms,
            "Makefile.PL - PL_FILES",
        );

        # TEST
        $makefile_pl->parse(qr{\A\s*PREREQ_PM *=> *\{\n\s*'Test::More' *=> *0,\n\s*\},\n}ms,
            "Makefile.PL - PREREQ_PM",
        );

    }

    {
        my $manifest = TestParseFile->new(
            {
                fn => File::Spec->catfile($module_base_dir, 'MANIFEST'),
            }
        );

        my $contents = <<"EOF";
Changes
lib/Book/Park/Mansfield.pm
lib/Book/Park/Mansfield/Base.pm
lib/Book/Park/Mansfield/FannyPrice.pm
lib/JAUSTEN/Utils.pm
Makefile.PL
MANIFEST\t\t\tThis list of files
README
t/00-load.t
t/manifest.t
t/pod-coverage.t
t/pod.t
EOF

        # TEST
        $manifest->consume(
            $contents,
            "MANIFEST for Makefile.PL'ed Module",
        );

        # TEST
        $manifest->is_end("MANIFEST - that's all folks!");
    }

    {
        my $mod1 = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib Book Park Mansfield.pm),
                ),
                perl_name   => 'Book::Park::Mansfield',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'apache',
            }
        );

        # TEST*$parse_module_start_num_tests
        $mod1->parse_module_start();

    }

    {
        my $jausten_mod = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib JAUSTEN Utils.pm),
                ),
                perl_name   => 'JAUSTEN::Utils',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'apache',
            }
        );

        # TEST*$parse_module_start_num_tests
        $jausten_mod->parse_module_start();
    }

    {
        my $mod2 = TestParseModuleFile->new(
            {
                fn => File::Spec->catfile(
                    $module_base_dir, qw(lib Book Park Mansfield Base.pm),
                ),
                perl_name   => 'Book::Park::Mansfield::Base',
                dist_name   => 'Book-Park-Mansfield',
                author_name => 'Jane Austen',
                license => 'apache',
            }
        );

        # TEST*$parse_module_start_num_tests
        $mod2->parse_module_start();

    }

    my $files_list;
    if (!$ENV{'DONT_DEL_APACHE'}) {
        rmtree ($module_base_dir, {result => \$files_list});
    }
}


=head1 NAME

t/test-dist.t - test the integrity of prepared distributions.

=head1 AUTHOR

Shlomi Fish, L<http://www.shlomifish.org/>
