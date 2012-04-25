#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Module::Starter;
use File::Spec;
use File::Path;
use Carp;

package TestParseFile;

use Test::More;
use File::Basename;

sub new {
    my $class = shift;
    my $self  = shift;
    $self //= {};
    $self->{_orig_vars} = { %$self };

    bless $self, $class;
    $self->_slurp_to_ref();
    
    return $self;
}

sub _text {
    my ($self, $text) = @_;
    
    if ($text) {
        unless (ref $text)             { $self->{_text} = \$text; }
        elsif  (ref $text eq 'SCALAR') { $self->{_text} = $text; }
        else                           { Carp::confess( 'Text must be a scalar type' ); }
    }

    return ${$self->{_text}};
}

sub _slurp_to_ref {
    my ($self) = @_;

    local $/;
    open my $in, '<', $self->{fn}
        or Carp::confess( "Cannot open ".$self->{fn} );
    $self->_text(<$in>);
    close($in);

    return $self->{_text};
}

sub _diag {
    my ($self) = @_;
    return diag explain $self->{_orig_vars};
}

sub parse {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ($self, $re, $msg) = @_;
    $msg ||= "Parsing $re";

    my $verdict = like($self->_text, $re, $self->format_msg($msg))
        or $self->_diag;

    ${$self->{_text}} =~ s{$re}{}ms if ($verdict);
        
    return $verdict;
}

sub consume {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ($self, $prefix, $msg) = @_;
    $msg ||= 'Contents';

    my $verdict =
        is( substr($self->_text, 0, length($prefix)),
            $prefix,
            $self->format_msg($msg))
        or $self->_diag;

    ${$self->{_text}} = substr($self->_text, length($prefix)) if ($verdict);

    return $verdict;
}

sub is_end {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ($self, $msg) = @_;
    $msg ||= "That's all folks!";

    my $verdict = is ($self->_text, "", $self->format_msg($msg))
        or $self->_diag;

    return $verdict;
}

# This is merely a copy of $LICENSES from Module::Starter::Simple.
# We could just use $Module::Starter::Simple::LICENSES, but really
# it's bad form to use variables from the actual modules for the
# purposes of testing.

our $LICENSES = {
    perl => {
        license => 'perl',
        slname  => 'Perl_5',
        url     => 'http://dev.perl.org/licenses/',
        blurb   => <<'EOT',
This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.
EOT
    },
    artistic => {
        license => 'artistic',
        slname  => 'Artistic_1_0',
        url     => 'http://www.perlfoundation.org/artistic_license_1_0',
        blurb   => <<'EOT',
This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (1.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_1_0>

Aggregation of this Package with a commercial distribution is always
permitted provided that the use of this Package is embedded; that is,
when no overt attempt is made to make this Package's interfaces visible
to the end user of the commercial distribution. Such use shall not be
construed as a distribution of this Package.

The name of the Copyright Holder may not be used to endorse or promote
products derived from this software without specific prior written
permission.

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
EOT
    },
    artistic2 => {
        license => 'artistic2',
        slname  => 'Artistic_2_0',
        url     => 'http://www.perlfoundation.org/artistic_license_2_0',
        blurb   => <<'EOT',
This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
EOT
    },
    mit => {
        license => 'mit',
        slname  => 'MIT',
        url     => 'http://www.opensource.org/licenses/mit-license.php',
        blurb   => <<'EOT',
This program is distributed under the MIT (X11) License:
L<http://www.opensource.org/licenses/mit-license.php>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
EOT
    },
    mozilla => {
        license => 'mozilla',
        slname  => 'Mozilla_1_1',
        url     => 'http://www.mozilla.org/MPL/1.1/',
        blurb   => <<'EOT',
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in
compliance with the License. You may obtain a copy of the License at
L<http://www.mozilla.org/MPL/>

Software distributed under the License is distributed on an "AS IS"
basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
License for the specific language governing rights and limitations
under the License.
EOT
    },
    mozilla2 => {
        license => 'mozilla2',
        slname  => 'Mozilla_2_0',
        url     => 'http://www.mozilla.org/MPL/2.0/',
        blurb   => <<'EOT',
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at L<http://mozilla.org/MPL/2.0/>.
EOT
    },
    bsd => {
        license => 'bsd',
        slname  => 'BSD',
        url     => 'http://www.opensource.org/licenses/BSD-3-Clause',
        blurb   => <<"EOT",
This program is distributed under the (Revised) BSD License:
L<http://www.opensource.org/licenses/BSD-3-Clause>

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

* Neither the name of ___AUTHOR___'s Organization
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
EOT
    },
    freebsd => {
        license => 'freebsd',
        slname  => 'FreeBSD',
        url     => 'http://www.opensource.org/licenses/BSD-2-Clause',
        blurb   => <<"EOT",
This program is distributed under the (Simplified) BSD License:
L<http://www.opensource.org/licenses/BSD-2-Clause>

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

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
EOT
    },
    cc0 => {
        license => 'cc0',
        slname  => 'CC0',
        url     => 'http://creativecommons.org/publicdomain/zero/1.0/',
        blurb   => <<'EOT',
This program is distributed under the CC0 1.0 Universal License:
L<http://creativecommons.org/publicdomain/zero/1.0/>

The person who associated a work with this deed has dedicated the work
to the public domain by waiving all of his or her rights to the work
worldwide under copyright law, including all related and neighboring
rights, to the extent allowed by law.

You can copy, modify, distribute and perform the work, even for
commercial purposes, all without asking permission. See Other
Information below.

Other Information:

* In no way are the patent or trademark rights of any person affected
by CC0, nor are the rights that other persons may have in the work or
in how the work is used, such as publicity or privacy rights. 

* Unless expressly stated otherwise, the person who associated a work
with this deed makes no warranties about the work, and disclaims
liability for all uses of the work, to the fullest extent permitted
by applicable law. 

* When using or citing the work, you should not imply endorsement by
the author or the affirmer.
EOT
    },
    gpl => {
        license => 'gpl',
        slname  => 'GPL_2',
        url     => 'http://www.gnu.org/licenses/gpl-2.0.html',
        blurb   => <<'EOT',
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
EOT
    },
    lgpl => {
        license => 'lgpl',
        slname  => 'LGPL_2',
        url     => 'http://www.gnu.org/licenses/lgpl-2.1.html',
        blurb   => <<'EOT',
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
EOT
    },
    gpl3 => {
        license => 'gpl3',
        slname  => 'GPL_3',
        url     => 'http://www.gnu.org/licenses/gpl-3.0.html',
        blurb   => <<'EOT',
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see L<http://www.gnu.org/licenses/>.
EOT
    },
    lgpl3 => {
        license => 'lgpl3',
        slname  => 'LGPL_3',
        url     => 'http://www.gnu.org/licenses/lgpl-3.0.html',
        blurb   => <<'EOT',
This program is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this program.  If not, see
L<http://www.gnu.org/licenses/>.
EOT
    },
    agpl3 => {
        license => 'agpl3',
        slname  => 'AGPL_2',
        url     => 'http://www.gnu.org/licenses/agpl-3.0.html',
        blurb => <<'EOT',
This program is free software; you can redistribute it and/or
modify it under the terms of the GNU Affero General Public
License as published by the Free Software Foundation; either
version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public
License along with this program.  If not, see
L<http://www.gnu.org/licenses/>.
EOT
    },
    apache => {
        license => 'apache',
        slname  => 'Apache_2_0',
        url     => 'http://www.apache.org/licenses/LICENSE-2.0',
        blurb   => <<'EOT',
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    L<http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
EOT
    },
    qpl => {
        license => 'qpl',
        slname  => 'QPL_1_0',
        url     => 'http://www.opensource.org/licenses/QPL-1.0',
        blurb   => <<'EOT',
This program is distributed under the Q Public License (QPL-1.0):
L<http://www.opensource.org/licenses/QPL-1.0>

The Software and this license document are provided AS IS with NO
WARRANTY OF ANY KIND, INCLUDING THE WARRANTY OF DESIGN, MERCHANTABILITY
AND FITNESS FOR A PARTICULAR PURPOSE.
EOT
    },
    
    
};

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

    return $self->parse( qr/$regex/ms, $msg );
}

sub format_msg {
    my ($self, $msg) = @_;

    return $msg;
}

=head2 $file_parser->parse_file_start

Parse the file based on the filename.  This will have various templates
on how to parse files of that type.

=cut

sub parse_file_start {
    my ($self) = @_;
    
    my $basefn  = basename($self->{fn});
    if ($basefn =~ /\.pm/) {
        return $self->parse_module_start() if (ref $self eq 'TestParseModuleFile');
        Carp::confess( "Wrong method for testing $basefn; use TestParseModuleFile" );
    }
    
    my $distro  = $self->{distro};
    my $mainmod = $self->{modules}[0];
    my $minperl = $self->{minperl} || 5.006;
    
    my $slname      = $LICENSES->{ $self->{license} }->{slname};
    my $license_url = $LICENSES->{ $self->{license} }->{url};
    
    (my $authoremail = "$self->{author} <$self->{email}>") =~ s/'/\'/g;
    (my $libmod = "lib/$mainmod".'.pm') =~ s|::|/|g;
    
    my $install_pl = $self->{builder} eq 'Module::Build' ? 'Build.PL' : 'Makefile.PL';
    my $manifest_skip = $self->{ignores_type} && !! grep { /manifest/ } @{ $self->{ignores_type} };
   
    if ($basefn =~ /\.pm/) {
        return $self->parse_module_start() if (ref $self eq 'TestParseModuleFile');
        Carp::confess( "Wrong method for testing $basefn; use TestParseModuleFile" );
    }
    
    my $msw_re  = qr{use \Q$minperl;\E\n\Quse strict;\E\n\Quse warnings FATAL => 'all';\E\n};
    my $mswb_re = $self->{builder} eq 'Module::Install' ? qr{\A$msw_re\Quse inc::$self->{builder};\E\n\n} : qr{\A$msw_re\Quse $self->{builder};\E\n\n};
    my $mswt_re = qr{\A\Q#!perl -T\E\n$msw_re\Quse Test::More;\E\n\n};
    
    if ($basefn eq 'README') {
        plan tests => 6;
        $self->parse(qr{\A\Q$distro\E\n\n}ms,
            "Starts with the package name",
        );

        $self->parse(qr{\AThe README is used to introduce the module and provide instructions.*?\n\n}ms,
            "README used to introduce",
        );

        $self->parse(
            qr{\AA README file is required for CPAN modules since CPAN extracts the.*?\n\n\n}ms,
            "A README file is required",
        );

        my $install_instr = $self->{builder} eq 'Module::Build' ?
            qr{\Qperl Build.PL\E\n\s+\Q./Build\E\n\s+\Q./Build test\E\n\s+\Q./Build install\E} :
            qr{\Qperl Makefile.PL\E\n\s+\Qmake\E\n\s+\Qmake test\E\n\s+\Qmake install\E};

        $self->parse(qr{\A\n*INSTALLATION\n\nTo install this module, run the following commands:\n\n\s+$install_instr\n\n},
            "INSTALLATION section",
        );

        $self->parse(qr{\ASUPPORT AND DOCUMENTATION\n\nAfter installing.*?^\s+perldoc \Q$mainmod\E\n\n}ms,
            "Support and docs 1"
        );

        $self->parse(qr{\AYou can also look for information at:\n\n\s+RT[^\n]+\n\s+\Qhttp://rt.cpan.org/NoAuth/Bugs.html?Dist=$distro\E\n\n}ms,
            "RT"
        );
    }
    elsif ($basefn eq 'Build.PL' && $self->{builder} eq 'Module::Build') {
        plan tests => 11;
        $self->parse($mswb_re,
            "Min/Strict/Warning/Builder"
        );

        $self->parse(qr{\A.*module_name *=> *'\Q$mainmod\E',\n}ms,
            "module_name",
        );

        $self->parse(qr{\A\s*license *=> *'$slname',\n}ms,
            "license",
        );

        $self->parse(qr{\A\s*dist_author *=> *\Qq{$authoremail},\E\n}ms,
            "dist_author",
        );

        $self->parse(qr{\A\s*dist_version_from *=> *\Q'$libmod',\E\n}ms,
            "dist_version_from",
        );

        $self->parse(qr{\A\s*release_status *=> *\Q'stable',\E\n}ms,
            "release_status",
        );

        $self->parse(
            qr/\A\s*configure_requires => \{\n *\Q'$self->{builder}' => 0\E,\n\s*\},\n/ms,
            "Configure Requires",
        );

        $self->parse(
            qr/\A\s*build_requires => \{\n *\Q'Test::More' => 0\E,\n\s*\},\n/ms,
            "Build Requires",
        );

        $self->parse(
            qr/\A\s*requires => \{\n *\Q#'ABC'\E *\Q=> 1.6,\E\n *\Q#'Foo::Bar::Module' => 5.0401,\E\n\s*\},\n/ms,
            "Requires",
        );

        $self->parse(
            qr/\A\s*add_to_cleanup *=> \Q[ '$distro-*' ],\E\n/ms,
            "add_to_cleanup",
        );

        $self->parse(
            qr/\A\s*create_makefile_pl *=> \Q'traditional',\E\n/ms,
            "create_makefile_pl",
        );
    }
    elsif ($basefn eq 'Makefile.PL' && $self->{builder} eq 'ExtUtils::MakeMaker') {
        plan tests => 11;
        $self->parse($mswb_re,
            "Min/Strict/Warning/Builder"
        );

        $self->parse(qr{\A.*NAME *=> *'$mainmod',\n}ms,
            "NAME",
        );

        $self->parse(qr{\A\s*AUTHOR *=> *\Qq{$authoremail},\E\n}ms,
            "AUTHOR",
        );

        $self->parse(qr{\A\s*VERSION_FROM *=> *\Q'$libmod',\E\n}ms,
            "VERSION_FROM",
        );

        $self->parse(qr{\A\s*ABSTRACT_FROM *=> *\Q'$libmod',\E\n}ms,
            "ABSTRACT_FROM",
        );

        $self->parse(qr{\A\s*LICENSE *=> *\Q'$slname',\E\n}ms,
            "LICENSE",
        );

        $self->parse(qr{\A\s*PL_FILES *=> *\{\},\n}ms,
            "PL_FILES",
        );

        $self->parse(qr{\A\s*MIN_PERL_VERSION *=> *\Q$minperl,\E\n}ms,
            "MIN_PERL_VERSION",
        );
        
        $self->parse(
            qr/\A\s*CONFIGURE_REQUIRES => \{\n *\Q'$self->{builder}' => 0\E,\n\s*\},\n/ms,
            "CONFIGURE_REQUIRES",
        );

        $self->parse(
            qr/\A\s*BUILD_REQUIRES => \{\n *\Q'Test::More' => 0\E,\n\s*\},\n/ms,
            "BUILD_REQUIRES",
        );

        $self->parse(
            qr/\A\s*PREREQ_PM => \{\n *\Q#'ABC'\E *\Q=> 1.6,\E\n *\Q#'Foo::Bar::Module' => 5.0401,\E\n\s*\},\n/ms,
            "PREREQ_PM",
        );
    }
    elsif ($basefn eq 'Makefile.PL' && $self->{builder} eq 'Module::Install') {
        plan tests => 13;
        $self->parse($mswb_re,
            "Min/Strict/Warning/Builder"
        );

        $self->parse(qr{\Aname\s+\Q'$distro';\E\n}ms,
            "name",
        );

        $self->parse(qr{\Aall_from\s+\Q'$libmod';\E\n}ms,
            "all_from",
        );

        $self->parse(qr{\Aauthor\s+\Qq{$authoremail};\E\n}ms,
            "author",
        );

        $self->parse(qr{\Alicense\s+\Q'$self->{license}';\E\n\n}ms,
            "license",
        );

        $self->parse(qr{\Aperl_version\s+\Q$minperl;\E\n\n}ms,
            "perl_version",
        );

        $self->parse(qr{\A\Qtests_recursive('t');\E\n\n}ms,
            "tests_recursive",
        );
        
        $self->consume(<<"EOT", 'resources');
resources (
   #homepage   => 'http://yourwebsitehere.com',
   #IRC        => 'irc://irc.perl.org/#$distro',
   license    => '$license_url',
   #repository => 'git://github.com/$self->{author}/$distro.git',
   bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=$distro',
);

EOT
        
        $self->parse(
            qr/\A\s*configure_requires \(\n *\Q'$self->{builder}' => 0\E,\n\s*\);\n/ms,
            "configure_requires",
        );

        $self->parse(
            qr/\A\s*build_requires \(\n *\Q'Test::More' => 0\E,\n\s*\);\n/ms,
            "build_requires",
        );

        $self->parse(
            qr/\A\s*requires \(\n *\Q#'ABC'\E *\Q=> 1.6,\E\n *\Q#'Foo::Bar::Module' => 5.0401,\E\n\s*\);\n/ms,
            "requires",
        );

        $self->consume(<<"EOF", 'Footer');

install_as_cpan;
auto_install;
WriteAll;
EOF

        $self->is_end();
    }
    elsif ($basefn eq 'Changes') {
        plan tests => 2;

        $self->consume(<<"EOF");
Revision history for $distro

0.01    Date/time
        First version, released on an unsuspecting world.

EOF

        $self->is_end();
    }
    elsif ($basefn eq 'MANIFEST' && !$manifest_skip) {
        plan tests => 2;
        $self->consume(join("\n", 
            ('Build.PL') x!! ($self->{builder} eq 'Module::Build'),
            'Changes',
            ( map { my $f = $_; $f =~ s|::|/|g; "lib/$f.pm"; } @{$self->{modules}} ),
            ('Makefile.PL') x!! ($self->{builder} ne 'Module::Build'),
            "MANIFEST\t\t\tThis list of files",
            qw(
                README
                t/00-load.t
                t/manifest.t
                t/pod-coverage.t
                t/pod.t
            )
        )."\n");

        $self->is_end();
    }
    elsif ($basefn eq 'MANIFEST.SKIP' && $manifest_skip) {
        plan tests => 2;
        $self->consume(<<'EOF');
# Top-level filter (only include the following...)
^(?!(?:script|examples|lib|inc|t|xt|maint)/|(?:(?:Makefile|Build)\.PL|README|MANIFEST|Changes|META\.(?:yml|json))$)

# Avoid version control files.
\bRCS\b
\bCVS\b
,v$
\B\.svn\b
\b_darcs\b
# (.git only in top-level, hence it's blocked above)

# Avoid temp and backup files.
~$
\.tmp$
\.old$
\.bak$
\..*?\.sw[po]$
\#$
\b\.#

# avoid OS X finder files
\.DS_Store$

# ditto for Windows
\bdesktop\.ini$
\b[Tt]humbs\.db$

# Avoid patch remnants
\.orig$
\.rej$
EOF

        $self->is_end();
    }
    elsif ($basefn =~ /^(?:ignore\.txt|\.(?:cvs|git)ignore)$/) {
        plan tests => ($manifest_skip ? 3 : 2);

        $self->consume("MANIFEST\nMANIFEST.bak\n", 'MANIFEST*') if ($manifest_skip);
        $self->consume(<<"EOF");
Makefile
Makefile.old
Build
Build.bat
META.*
MYMETA.*
.build/
_build/
cover_db/
blib/
inc/
.lwpcookies
.last_cover_stats
nytprof.out
pod2htm*.tmp
$distro-*
$distro-*.tar.gz
EOF

        $self->is_end();
    }
    elsif ($basefn eq '00-load.t') {
        my $cnt = scalar @{$self->{modules}};
        plan tests => $cnt + 4;

        $self->parse($mswt_re,
            "#!perl/Min/Strict/Warning/Test::More"
        );

        $self->consume(<<"EOH", 'Plan Header');
plan tests => $cnt;

BEGIN {
EOH
        foreach my $module (@{$self->{modules}}) {
            $self->consume(<<"EOM", $module);
    use_ok( '$module' ) || print "Bail out!\\n";
EOM
        }
        
        my $escape_version = '$'.$mainmod.'::VERSION';
        $self->consume(<<"EOF", 'Footer');
}

diag( "Testing $mainmod $escape_version, Perl \$], \$^X" );
EOF

        $self->is_end();
    }
    elsif ($basefn eq 'boilerplate.t') {
        my $cnt = scalar @{$self->{modules}} + 2;
        plan tests => $cnt + 3;

        $self->parse($mswt_re,
            "#!perl/Min/Strict/Warning/Test::More"
        );

        $self->consume(<<"EOH", 'Plan Header');
plan tests => $cnt;

EOH

        $self->consume(<<'EOT', 'Sub declares');
sub not_in_file_ok {
    my ($filename, %regex) = @_;
    open( my $fh, '<', $filename )
        or die "couldn't open $filename for reading: $!";

    my %violated;

    while (my $line = <$fh>) {
        while (my ($desc, $regex) = each %regex) {
            if ($line =~ $regex) {
                push @{$violated{$desc}||=[]}, $.;
            }
        }
    }

    if (%violated) {
        fail("$filename contains boilerplate text");
        diag "$_ appears on lines @{$violated{$_}}" for keys %violated;
    } else {
        pass("$filename contains no boilerplate text");
    }
}

sub module_boilerplate_ok {
    my ($module) = @_;
    not_in_file_ok($module =>
        'the great new $MODULENAME'   => qr/ - The great new /,
        'boilerplate description'     => qr/Quick summary of what the module/,
        'stub function definition'    => qr/function[12]/,
    );
}

TODO: {
  local $TODO = "Need to replace the boilerplate text";

  not_in_file_ok(README =>
    "The README is used..."       => qr/The README is used/,
    "'version information here'"  => qr/to provide version information/,
  );

  not_in_file_ok(Changes =>
    "placeholder date/time"       => qr(Date/time)
  );
EOT
        foreach my $module (@{$self->{modules}}) {
            (my $modre = 'lib::'.$module.'\.pm') =~ s|::|'[:/]'|ge;  # only : for Mac, and / for all others (including Windows)
            $self->parse(qr{\A\s*module_boilerplate_ok\(\'$modre\'\)\;\n}, $module);
        }
        
        $self->parse(qr{\A\s*\}\s*}ms, 'Footer');

        $self->is_end();
    }
    elsif ($basefn eq 'manifest.t') {
        plan tests => 3;

        $self->parse($mswt_re,
            "#!perl/Min/Strict/Warning/Test::More"
        );

        my $minimal_test_checkmanifest = '0.9';
        $self->consume(<<"EOF");
unless ( \$ENV{RELEASE_TESTING} ) {
    plan( skip_all => "Author tests not required for installation" );
}

my \$min_tcm = $minimal_test_checkmanifest;
eval "use Test::CheckManifest \$min_tcm";
plan skip_all => "Test::CheckManifest \$min_tcm required" if \$\@;

ok_manifest();
EOF

        $self->is_end();
    }
    elsif ($basefn eq 'pod.t') {
        plan tests => 3;

        $self->parse($mswt_re,
            "#!perl/Min/Strict/Warning/Test::More"
        );

        my $minimal_test_pod = "1.22";
        $self->consume(<<"EOF");
# Ensure a recent version of Test::Pod
my \$min_tp = $minimal_test_pod;
eval "use Test::Pod \$min_tp";
plan skip_all => "Test::Pod \$min_tp required for testing POD" if \$\@;

all_pod_files_ok();
EOF

        $self->is_end();
    }
    elsif ($basefn eq 'pod-coverage.t') {
        plan tests => 5;

        $self->parse($mswt_re,
            "#!perl/Min/Strict/Warning/Test::More"
        );

        my $l1 = q{eval "use Test::Pod::Coverage $min_tpc";};

        $self->parse(
            qr/\A# Ensure a recent[^\n]+\nmy \$min_tpc = \d+\.\d+;\n\Q$l1\E\nplan skip_all[^\n]+\n *if \$\@;\n\n/ms,
            'min_tpc block',
        );

        $l1 = q{eval "use Pod::Coverage $min_pc";};

        $self->parse(
            qr/\A(?:# [^\n]+\n)*my \$min_pc = \d+\.\d+;\n\Q$l1\E\nplan skip_all[^\n]+\n *if \$\@;\n\n/ms,
            'min_pod_coverage block',
        );

        $self->parse(
            qr/all_pod_coverage_ok\(\);\n/,
            'all_pod_coverage_ok',
        );

        $self->is_end();
    }
    else {
        $self->_diag;
        Carp::confess( "No testing template for $basefn" );
    }

    done_testing();
    return;
}

package TestParseModuleFile;

use parent qw(-norequire TestParseFile);

sub parse_module_start {
    my $self = shift;

    my $perl_name    = $self->{module};
    my $dist_name    = $self->{distro};
    my $author_name  = $self->{author};
    my $lc_dist_name = lc($dist_name);
    my $minperl      = $self->{minperl} || 5.006;
    
    Test::More::plan tests => 19;

    $self->parse(
        qr/\Apackage \Q$perl_name\E;\n\nuse $minperl;\nuse strict;\n\Quse warnings FATAL => 'all';\E\n\n/ms,
        'start',
    );

    {
        my $s1 = qq{$perl_name - The great new $perl_name!};

        $self->parse(
            qr/\A=head1 NAME\n\n\Q$s1\E\n\n/ms,
            "NAME Pod.",
        );
    }

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

        $self->parse_paras(
            \@synopsis_paras,
            'SYNOPSIS',
        );
    }

    $self->parse_paras(
        [
            '=head1 EXPORT',
              "A list of functions that can be exported.  You can delete this section\n"
            . "if you don't export anything, such as for a purely object-oriented module.",
        ],
        "EXPORT",
    );

    $self->parse_paras(
        [
            "=head1 SUBROUTINES/METHODS",
            "=head2 function1",
            "=cut",
            "sub function1 {\n}",
        ],
        "function1",
    );

    $self->parse_paras(
        [
            "=head2 function2",
            "=cut",
            "sub function2 {\n}",
        ],
        "function2",
    );

    $self->parse_paras(
        [
            "=head1 AUTHOR",
            { re => quotemeta($author_name) . q{[^\n]+} },
        ],
        "AUTHOR",
    );

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

    $self->parse_paras(
        [
            { re => q/=item \* RT:[^\n]*/, },
            "L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=$dist_name>",
        ],
        "Support - RT",
    );


    $self->parse_paras(
        [
            { re => q/=item \* AnnoCPAN:[^\n]*/, },
            "L<http://annocpan.org/dist/$dist_name>",
        ],
        "AnnoCPAN",
    );

    $self->parse_paras(
        [
            { re => q/=item \* CPAN Ratings[^\n]*/, },
            "L<http://cpanratings.perl.org/d/$dist_name>",
        ],
        "CPAN Ratings",
    );

    $self->parse_paras(
        [
            { re => q/=item \* Search CPAN[^\n]*/, },
            "L<http://search.cpan.org/dist/$dist_name/>",
        ],
        "CPAN Ratings",
    );

    $self->parse_paras(
        [
            "=back",
        ],
        "Support - =back",
    );

    $self->parse_paras(
        [
            "=head1 ACKNOWLEDGEMENTS",
        ],
        "acknowledgements",
    );

    my $license_blurb = $LICENSES->{ $self->{license} }->{blurb};
    $license_blurb =~ s/___AUTHOR___/$author_name/ge;
    $self->parse_paras(
        [
            "=head1 LICENSE AND COPYRIGHT",
            { re =>
                  q/Copyright \d+ /
                . quotemeta($author_name)
                . q/\./
            },
            split(/\n\n+/, $license_blurb ),
        ],
        "copyright",
    );

    $self->parse_paras(
        [
            "=cut",
        ],
        "=cut POD end",
    );

    $self->consume(
        qq{1; # End of $perl_name},
        "End of module",
    );

    return;
}


package main;

use File::Find;

# Since we are going into randomization with tests, seed saving is now important.
# rand calls srand automatically, then we re-seed.  Perl 5.14 would allow us to 
# just get the seed value from a srand() call, but we aren't there yet...
my $random_seed = int(rand() * 2**32);
srand($random_seed);

sub run_settest {
    my ($base_dir, $distro_var) = @_;
    my $module_base_dir = File::Spec->catdir(qw(t data), ref $base_dir ? @$base_dir : $base_dir);
    $distro_var->{dir} = $module_base_dir;

    subtest 'Set ==> '.$distro_var->{modules}[0] => sub {
        Module::Starter->create_distro( %$distro_var );
        
        $distro_var->{__srand} = $random_seed;

        my $manifest_skip = $distro_var->{ignores_type} && !! grep { /manifest/ } @{ $distro_var->{ignores_type} };
        my @exist_files = (
            qw(README Changes),
            $manifest_skip ? 'MANIFEST.SKIP' : 'MANIFEST',
            $distro_var->{builder} eq 'Module::Build' ? 'Build.PL' : 'Makefile.PL',
            [qw(t 00-load.t)],
            [qw(t boilerplate.t)],
            [qw(t manifest.t)],
            [qw(t pod.t)],
            [qw(t pod-coverage.t)],
        );
        
        # Make sure we are actually testing every single file
        my @test_files;
        my $base_cnt = scalar File::Spec->splitdir($module_base_dir);
        find({
            no_chdir => 1,
            wanted => sub {
                -f and do {
                    my @dirs = File::Spec->splitdir($_);
                    @dirs = splice(@dirs, $base_cnt);  # delete base_dir
                    return if ($dirs[0] eq 'lib' && $dirs[-1] =~ /\.pm$/);
                    
                    push(@test_files,
                        @dirs == 1 ? $dirs[0] : \@dirs
                    );
                };
            }
        }, $module_base_dir);
        
        plan tests => (@exist_files + @test_files + @{$distro_var->{modules}});
        
        # File existence tests
        foreach my $arrfile (@exist_files) {
            my $file = ref $arrfile ? File::Spec->catfile(@$arrfile) : $arrfile;
            ok(-f File::Spec->catfile($module_base_dir, $file), "Exists: $file");
        }

        # Standard file tests
        foreach my $arrfile (@test_files) {
            my $file = ref $arrfile ? File::Spec->catfile(@$arrfile) : $arrfile;
            subtest $file => sub {
                TestParseFile->new(
                    { fn => File::Spec->catfile($module_base_dir, $file), %$distro_var }
                )->parse_file_start();
            };
        }
        
        # Module tests
        foreach my $module (@{$distro_var->{modules}}) {
            subtest $module => sub {
                TestParseModuleFile->new({
                    fn => File::Spec->catfile($module_base_dir, 'lib', split(/::/, "$module.pm")),
                    module => $module,
                    %$distro_var
                })->parse_module_start();
            };
        }

        rmtree $module_base_dir unless ($ENV{'DONT_DEL_TEST_DIST'});
    };
}

my @rand_char = split //, '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_';
sub rstr {
    my $str = '';
    my $len = int(rand(20)) + 1;
    $str .= $rand_char[ int(rand(@rand_char)) ] for (1 .. $len);
    return $str;
}
sub rstr_array {
    my @str;
    my $len = int(rand(5)) + 1;
    push(@str, rstr) for (1 .. $len);
    return @str;
}
sub rstr_module {
    my @str;
    my $len = int(rand(5)) + 1;
    push(@str, rstr) for (1 .. $len);
    
    while ($str[0] =~ /^\d+/) {
        $str[0] =~ s/^\d+//;
        shift @str unless ($str[0]);
        return &rstr_module unless (@str);
    }
    
    return join('::', @str);
}

plan tests => 5;

my $DONT_DEL = $ENV{'DONT_DEL_TEST_DIST'};
run_settest('MyModule-Test', {
    distro  => 'MyModule-Test',
    modules => ['MyModule::Test', 'MyModule::Test::App'],
    builder => 'Module::Build',
    license => 'perl',
    author  => 'Baruch Spinoza',
    email   => 'spinoza@philosophers.tld',
    verbose => 0,
    force   => $DONT_DEL,    
});

run_settest('Book-Park-Mansfield', {
    distro  => 'Book-Park-Mansfield',
    modules => [
        'Book::Park::Mansfield',
        'Book::Park::Mansfield::Base',
        'Book::Park::Mansfield::FannyPrice',
        'JAUSTEN::Utils',
    ],
    builder => 'Module::Build',
    license => 'perl',
    author  => 'Jane Austen',
    email   => 'jane.austen@writers.tld',
    verbose => 0,
    force   => $DONT_DEL,
});

# Test all variations of everything

# To make sure that we capture any new licenses, we can grab
# $Module::Starter::Simple::LICENSES and check the keys.
# Thus, any desyncs between here and there will fail tests.
my @licenses = keys %$Module::Starter::Simple::LICENSES;

foreach my $builder (qw(ExtUtils::MakeMaker Module::Build Module::Install)) {
subtest "builder = $builder" => sub {
    undef $@;
    eval "require $builder";  # require hates string class names; must use eval string instead of block
    plan ($@ ? 
        (skip_all => $builder.' not installed') : 
        (tests => scalar @licenses)
    );

    foreach my $license (@licenses) {
    subtest "license = $license" => sub {
        plan tests => 5;

        foreach my $minperl (5.006, 5.008001, v5.10.0, 'v5.10.1', $^V) {
        subtest "minperl = $minperl" => sub {
            plan ($minperl > $^V ? 
                (skip_all => $minperl.' is actually newer than Perl version ($^V)') : 
                (tests => 16)
            );

            foreach my $it (0..15) {
            subtest "ignores_type = ".substr(unpack("B8", pack("C", $it)), 4) => sub {

                # Only run through 1% of these tests, since there's so many combinations
                # (But, always do both force tests.)
                plan ((rand() > .01) ? 
                    (skip_all => 'Only testing a 1% sample') : 
                    (tests => 2)
                );

                # This stuff should always be the same for both force tests.
                # Force tests should always been last (innermost) in the loop as well.
                my $distro = join('-', rstr_array);
                my $author = rstr.' '.rstr;
                my $email  = join('.', rstr_array).'@'.join('.', rstr_array).'.tld';

                my @modules;
                my $len = int(rand(20)) + 1;
                push(@modules, rstr_module ) for (1 .. $len);
                @modules = sort {
                    # match the sorting to exactly what the MANIFEST lists would look like
                    my ($q, $r) = ($a, $b);
                    $q =~ s|::|/|g;
                    $r =~ s|::|/|g;
                    return lc $q cmp lc $r;
                } @modules;
                
                foreach my $force (0, 1) {
                subtest "force = $force" => sub {
                    $ENV{'DONT_DEL_TEST_DIST'} = !$force || $DONT_DEL;
                    
                    run_settest(['loop', $distro], {  # store these in its own directory
                        distro  => $distro,
                        modules => \@modules,
                        builder => $builder,
                        license => $license,
                        author  => $author,
                        email   => $email,
                        minperl => $minperl,
                        verbose => 0,
                        force   => $force,
                        ignores_type => [
                            ('generic')  x!! ($it | 8),
                            ('cvs')      x!! ($it | 4),
                            ('git')      x!! ($it | 2),
                            ('manifest') x!! ($it | 1),
                        ],
                    });
                    
                }; }
            }; }
        }; }
    }; }
}; }

$ENV{'DONT_DEL_TEST_DIST'} = $DONT_DEL;
my $loop_dir = File::Spec->catdir(qw(t data loop));
rmtree $loop_dir if (-d $loop_dir && !$DONT_DEL);

1;

=head1 NAME

t/test-dist.t - test the integrity of prepared distributions.

=head1 AUTHOR

Shlomi Fish, L<http://www.shlomifish.org/>
Heavy revamp by Brendan Byrd, L<BBYRD@CPAN.org>
