package Module::Starter::Simple;

use 5.006;
use strict;
use warnings;

use Cwd 'cwd';
use ExtUtils::Command qw( rm_rf mkpath touch );
use File::Spec ();
use Carp qw( carp confess croak );

use Module::Starter::BuilderSet;

=head1 NAME

Module::Starter::Simple - a simple, comprehensive Module::Starter plugin

=head1 VERSION

Version 1.61

=cut

our $VERSION = '1.61';

=head1 SYNOPSIS

    use Module::Starter qw(Module::Starter::Simple);

    Module::Starter->create_distro(%args);

=head1 DESCRIPTION

Module::Starter::Simple is a plugin for Module::Starter that will perform all
the work needed to create a distribution.  Given the parameters detailed in
L<Module::Starter>, it will create content, create directories, and populate
the directories with the required files.

=head1 CLASS METHODS

=head2 C<< new(%args) >>

This method is called to construct and initialize a new Module::Starter object.
It is never called by the end user, only internally by C<create_distro>, which
creates ephemeral Module::Starter objects.  It's documented only to call it to
the attention of subclass authors.

=cut

sub new {
    my $class = shift;
    return bless { @_ } => $class;
}

=head1 OBJECT METHODS

All the methods documented below are object methods, meant to be called
internally by the ephemeral objects created during the execution of the class
method C<create_distro> above.

=head2 postprocess_config

A hook to do any work after the configuration is initially processed.

=cut

sub postprocess_config { 1 };

=head2 pre_create_distro

A hook to do any work right before the distro is created.

=cut

sub pre_create_distro { 1 };

=head2 C<< create_distro(%args) >>

This method works as advertised in L<Module::Starter>.

=cut

sub create_distro {
    my $either = shift;

    ( ref $either ) or $either = $either->new( @_ );

    my $self    = $either;
    my $modules = $self->{modules} || [];
    my @modules = map { split /,/ } @{$modules};
    croak "No modules specified.\n" unless @modules;
    for (@modules) {
        croak "Invalid module name: $_" unless /\A[a-z_]\w*(?:::[\w]+)*\Z/i;
    }

    if ( ( not $self->{author} ) && ( $^O ne 'MSWin32' ) ) {
        ( $self->{author} ) = split /,/, ( getpwuid $> )[6];
    }

    if ( not $self->{email} and exists $ENV{EMAIL} ) {
        $self->{email} = $ENV{EMAIL};
    }

    croak "Must specify an author\n" unless $self->{author};
    croak "Must specify an email address\n" unless $self->{email};
    ($self->{email_obfuscated} = $self->{email}) =~ s/@/ at /;

    $self->{license}      ||= 'artistic2';
    $self->{minperl}      ||= 5.006;
    $self->{ignores_type} ||= ['generic'];
    $self->{manifest_skip} = !! grep { /manifest/ } @{ $self->{ignores_type} };
    
    $self->{license_record} = $self->_license_record();

    $self->{main_module} = $modules[0];
    if ( not $self->{distro} ) {
        $self->{distro} = $self->{main_module};
        $self->{distro} =~ s/::/-/g;
    }

    $self->{basedir} = $self->{dir} || $self->{distro};
    $self->create_basedir;

    my @files;
    push @files, $self->create_modules( @modules );

    push @files, $self->create_t( @modules );
    push @files, $self->create_ignores;
    my %build_results = $self->create_build();
    push(@files, @{ $build_results{files} } );

    push @files, $self->create_Changes;
    push @files, $self->create_README( $build_results{instructions} );

    $self->create_MANIFEST( $build_results{'manifest_method'} ) unless ( $self->{manifest_skip} );
    # TODO: put files to ignore in a more standard form?
    # XXX: no need to return the files created

    return;
}

=head2 post_create_distro

A hook to do any work after creating the distribution.

=cut

sub post_create_distro { 1 };

=head2 pre_exit

A hook to do any work right before exit time.

=cut

sub pre_exit {
     print "Created starter directories and files\n";
}

=head2 create_basedir

Creates the base directory for the distribution.  If the directory already
exists, and I<$force> is true, then the existing directory will get erased.

If the directory can't be created, or re-created, it dies.

=cut

sub create_basedir {
    my $self = shift;

    # Make sure there's no directory
    if ( -e $self->{basedir} ) {
        die( "$self->{basedir} already exists.  ".
             "Use --force if you want to stomp on it.\n"
            ) unless $self->{force};

        local @ARGV = $self->{basedir};
        rm_rf();

        die "Couldn't delete existing $self->{basedir}: $!\n"
          if -e $self->{basedir};
    }

    CREATE_IT: {
        $self->progress( "Created $self->{basedir}" );

        local @ARGV = $self->{basedir};
        mkpath();

        die "Couldn't create $self->{basedir}: $!\n" unless -d $self->{basedir};
    }

    return;
}

=head2 create_modules( @modules )

This method will create a starter module file for each module named in
I<@modules>.

=cut

sub create_modules {
    my $self = shift;
    my @modules = @_;

    my @files;

    for my $module ( @modules ) {
        my $rtname = lc $module;
        $rtname =~ s/::/-/g;
        push @files, $self->_create_module( $module, $rtname );
    }

    return @files;
}

=head2 module_guts( $module, $rtname )

This method returns the text which should serve as the contents for the named
module.  I<$rtname> is the email suffix which rt.cpan.org will use for bug
reports.  (This should, and will, be moved out of the parameters for this
method eventually.)

=cut

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

sub _license_record { $LICENSES->{ shift->{license} }; }

sub _license_blurb {
    my $self = shift;

    my $record = $self->{license_record};
    my $license_blurb = defined($record) ?
        $record->{blurb} :
        <<"EOT";
This program is released under the following license: $self->{license}
EOT

    $license_blurb =~ s/___AUTHOR___/$self->{author}/ge;
    chomp $license_blurb;
    return $license_blurb;
}

# _create_module: used by create_modules to build each file and put data in it

sub _create_module {
    my $self = shift;
    my $module = shift;
    my $rtname = shift;

    my @parts = split( /::/, $module );
    my $filepart = (pop @parts) . '.pm';
    my @dirparts = ( $self->{basedir}, 'lib', @parts );
    my $SLASH = q{/};
    my $manifest_file = join( $SLASH, 'lib', @parts, $filepart );
    if ( @dirparts ) {
        my $dir = File::Spec->catdir( @dirparts );
        if ( not -d $dir ) {
            local @ARGV = $dir;
            mkpath @ARGV;
            $self->progress( "Created $dir" );
        }
    }

    my $module_file = File::Spec->catfile( @dirparts,  $filepart );

    $self->{module_file}{$module} = File::Spec->catfile('lib', @parts, $filepart);
    $self->create_file( $module_file, $self->module_guts( $module, $rtname ) );
    $self->progress( "Created $module_file" );

    return $manifest_file;
}

sub _thisyear {
    return (localtime())[5] + 1900;
}

sub _module_to_pm_file {
    my $self = shift;
    my $module = shift;

    my @parts = split( /::/, $module );
    my $pm = pop @parts;
    my $pm_file = File::Spec->catfile( 'lib', @parts, "${pm}.pm" );
    $pm_file =~ s{\\}{/}g; # even on Win32, use forward slash

    return $pm_file;
}

sub _reference_links {
  return (
      { nickname => 'RT',
        title    => 'CPAN\'s request tracker (report bugs here)',
        link     => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=%s',
      },
      { nickname => 'AnnoCPAN',
        title    => 'Annotated CPAN documentation',
        link     => 'http://annocpan.org/dist/%s',
      },
      { title    => 'CPAN Ratings',
        link     => 'http://cpanratings.perl.org/d/%s',
      },
      { title    => 'Search CPAN',
        link     => 'http://search.cpan.org/dist/%s/',
      },
    );
}

=head2 create_Makefile_PL( $main_module )

This will create the Makefile.PL for the distribution, and will use the module
named in I<$main_module> as the main module of the distribution.

=cut

sub create_Makefile_PL {
    my $self         = shift;
    my $main_module  = shift;
    my $builder_name = 'ExtUtils::MakeMaker';
    my $output_file  =
    Module::Starter::BuilderSet->new()->file_for_builder($builder_name);
    my $fname        = File::Spec->catfile( $self->{basedir}, $output_file );

    $self->create_file(
        $fname,
        $self->Makefile_PL_guts(
            $main_module,
            $self->_module_to_pm_file($main_module),
        ),
    );

    $self->progress( "Created $fname" );

    return $output_file;
}

=head2 create_MI_Makefile_PL( $main_module )

This will create a Module::Install Makefile.PL for the distribution, and will
use the module named in I<$main_module> as the main module of the distribution.

=cut

sub create_MI_Makefile_PL {
    my $self         = shift;
    my $main_module  = shift;
    my $builder_name = 'Module::Install';
    my $output_file  =
      Module::Starter::BuilderSet->new()->file_for_builder($builder_name);
    my $fname        = File::Spec->catfile( $self->{basedir}, $output_file );

    $self->create_file(
        $fname,
        $self->MI_Makefile_PL_guts(
            $main_module,
            $self->_module_to_pm_file($main_module),
        ),
    );

    $self->progress( "Created $fname" );

    return $output_file;
}

=head2 Makefile_PL_guts( $main_module, $main_pm_file )

This method is called by create_Makefile_PL and returns text used to populate
Makefile.PL; I<$main_pm_file> is the filename of the distribution's main
module, I<$main_module>.

=cut

sub Makefile_PL_guts {
    my $self = shift;
    my $main_module = shift;
    my $main_pm_file = shift;

    (my $author = "$self->{author} <$self->{email}>") =~ s/'/\'/g;
    
    my $slname = $self->{license_record} ? $self->{license_record}->{slname} : $self->{license};

    return <<"HERE";
use $self->{minperl};
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => '$main_module',
    AUTHOR           => q{$author},
    VERSION_FROM     => '$main_pm_file',
    ABSTRACT_FROM    => '$main_pm_file',
    LICENSE          => '$slname',
    PL_FILES         => {},
    MIN_PERL_VERSION => $self->{minperl},
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        #'ABC'              => 1.6,
        #'Foo::Bar::Module' => 5.0401,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => '$self->{distro}-*' },
);
HERE

}

=head2 MI_Makefile_PL_guts( $main_module, $main_pm_file )

This method is called by create_MI_Makefile_PL and returns text used to populate
Makefile.PL; I<$main_pm_file> is the filename of the distribution's main
module, I<$main_module>.

=cut

sub MI_Makefile_PL_guts {
    my $self = shift;
    my $main_module = shift;
    my $main_pm_file = shift;

    my $author = "$self->{author} <$self->{email}>";
    $author =~ s/'/\'/g;
    
    my $license_url = $self->{license_record} ? $self->{license_record}->{url} : '';

    return <<"HERE";
use $self->{minperl};
use strict;
use warnings FATAL => 'all';
use inc::Module::Install;

name     '$self->{distro}';
all_from '$main_pm_file';
author   q{$author};
license  '$self->{license}';

perl_version $self->{minperl};

tests_recursive('t');

resources (
   #homepage   => 'http://yourwebsitehere.com',
   #IRC        => 'irc://irc.perl.org/#$self->{distro}',
   license    => '$license_url',
   #repository => 'git://github.com/$self->{author}/$self->{distro}.git',
   bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=$self->{distro}',
);

configure_requires (
   'Module::Install' => 0,
);

build_requires (
   'Test::More' => 0,
);

requires (
   #'ABC'              => 1.6,
   #'Foo::Bar::Module' => 5.0401,
);

install_as_cpan;
auto_install;
WriteAll;
HERE

}

=head2 create_Build_PL( $main_module )

This will create the Build.PL for the distribution, and will use the module
named in I<$main_module> as the main module of the distribution.

=cut

sub create_Build_PL {
    my $self         = shift;
    my $main_module  = shift;
    my $builder_name = 'Module::Build';
    my $output_file  =
      Module::Starter::BuilderSet->new()->file_for_builder($builder_name);
    my $fname        = File::Spec->catfile( $self->{basedir}, $output_file );

    $self->create_file(
        $fname,
        $self->Build_PL_guts(
            $main_module,
            $self->_module_to_pm_file($main_module),
        ),
    );

    $self->progress( "Created $fname" );

    return $output_file;
}

=head2 Build_PL_guts( $main_module, $main_pm_file )

This method is called by create_Build_PL and returns text used to populate
Build.PL; I<$main_pm_file> is the filename of the distribution's main module,
I<$main_module>.

=cut

sub Build_PL_guts {
    my $self = shift;
    my $main_module = shift;
    my $main_pm_file = shift;

    (my $author = "$self->{author} <$self->{email}>") =~ s/'/\'/g;

    my $slname = $self->{license_record} ? $self->{license_record}->{slname} : $self->{license};
    
    return <<"HERE";
use $self->{minperl};
use strict;
use warnings FATAL => 'all';
use Module::Build;

my \$builder = Module::Build->new(
    module_name         => '$main_module',
    license             => '$slname',
    dist_author         => q{$author},
    dist_version_from   => '$main_pm_file',
    release_status      => 'stable',
    configure_requires => {
        'Module::Build' => 0,
    },
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        #'ABC'              => 1.6,
        #'Foo::Bar::Module' => 5.0401,
    },
    add_to_cleanup     => [ '$self->{distro}-*' ],
    create_makefile_pl => 'traditional',
);

\$builder->create_build_script();
HERE

}

=head2 create_Changes( )

This method creates a skeletal Changes file.

=cut

sub create_Changes {
    my $self = shift;

    my $fname = File::Spec->catfile( $self->{basedir}, 'Changes' );
    $self->create_file( $fname, $self->Changes_guts() );
    $self->progress( "Created $fname" );

    return 'Changes';
}

=head2 Changes_guts

Called by create_Changes, this method returns content for the Changes file.

=cut

sub Changes_guts {
    my $self = shift;

    return <<"HERE";
Revision history for $self->{distro}

0.01    Date/time
        First version, released on an unsuspecting world.

HERE
}

=head2 create_README( $build_instructions )

This method creates the distribution's README file.

=cut

sub create_README {
    my $self = shift;
    my $build_instructions = shift;

    my $fname = File::Spec->catfile( $self->{basedir}, 'README' );
    $self->create_file( $fname, $self->README_guts($build_instructions) );
    $self->progress( "Created $fname" );

    return 'README';
}

=head2 README_guts

Called by create_README, this method returns content for the README file.

=cut

sub _README_intro {
    my $self = shift;

    return <<"HERE";
The README is used to introduce the module and provide instructions on
how to install the module, any machine dependencies it may have (for
example C compilers and installed libraries) and any other information
that should be provided before the module is installed.

A README file is required for CPAN modules since CPAN extracts the README
file from a module distribution so that people browsing the archive
can use it to get an idea of the module's uses. It is usually a good idea
to provide version information here so that people can decide whether
fixes for the module are worth downloading.
HERE
}

sub _README_information {
    my $self = shift;

    my @reference_links = _reference_links();

    my $content = "You can also look for information at:\n";

    foreach my $ref (@reference_links){
        my $title;
        $title = "$ref->{nickname}, " if exists $ref->{nickname};
        $title .= $ref->{title};
        my $link  = sprintf($ref->{link}, $self->{distro});

        $content .= qq[
    $title
        $link
];
    }

    return $content;
}

sub _README_license {
    my $self = shift;

    my $year          = $self->_thisyear();
    my $license_blurb = $self->_license_blurb();

return <<"HERE";
LICENSE AND COPYRIGHT

Copyright (C) $year $self->{author}

$license_blurb
HERE
}

sub README_guts {
    my $self = shift;
    my $build_instructions = shift;

    my $intro         = $self->_README_intro();
    my $information   = $self->_README_information();
    my $license       = $self->_README_license();

return <<"HERE";
$self->{distro}

$intro

INSTALLATION

$build_instructions

SUPPORT AND DOCUMENTATION

After installing, you can find documentation for this module with the
perldoc command.

    perldoc $self->{main_module}

$information

$license
HERE
}

=head2 create_t( @modules )

This method creates a bunch of *.t files.  I<@modules> is a list of all modules
in the distribution.

=cut

sub create_t {
    my $self = shift;
    my @modules = @_;

    my %t_files = $self->t_guts(@modules);

    my @files = map { $self->_create_t($_, $t_files{$_}) } keys %t_files;

    return @files;
}

=head2 t_guts( @modules )

This method is called by create_t, and returns a description of the *.t files
to be created.

The return value is a hash of test files to create.  Each key is a filename and
each value is the contents of that file.

=cut

sub t_guts {
    my $self = shift;
    my @modules = @_;

    my %t_files;
    my $minperl = $self->{minperl};
    my $header = <<"EOH";
#!perl -T
use $minperl;
use strict;
use warnings FATAL => 'all';
use Test::More;

EOH
    
    $t_files{'pod.t'} = $header.<<'HERE';
# Ensure a recent version of Test::Pod
my $min_tp = 1.22;
eval "use Test::Pod $min_tp";
plan skip_all => "Test::Pod $min_tp required for testing POD" if $@;

all_pod_files_ok();
HERE

    $t_files{'manifest.t'} = $header.<<'HERE';
unless ( $ENV{RELEASE_TESTING} ) {
    plan( skip_all => "Author tests not required for installation" );
}

my $min_tcm = 0.9;
eval "use Test::CheckManifest $min_tcm";
plan skip_all => "Test::CheckManifest $min_tcm required" if $@;

ok_manifest();
HERE

    $t_files{'pod-coverage.t'} = $header.<<'HERE';
# Ensure a recent version of Test::Pod::Coverage
my $min_tpc = 1.08;
eval "use Test::Pod::Coverage $min_tpc";
plan skip_all => "Test::Pod::Coverage $min_tpc required for testing POD coverage"
    if $@;

# Test::Pod::Coverage doesn't require a minimum Pod::Coverage version,
# but older versions don't recognize some common documentation styles
my $min_pc = 0.18;
eval "use Pod::Coverage $min_pc";
plan skip_all => "Pod::Coverage $min_pc required for testing POD coverage"
    if $@;

all_pod_coverage_ok();
HERE

    my $nmodules = @modules;
    my $main_module = $modules[0];
    my $use_lines = join(
        "\n", map { qq{    use_ok( '$_' ) || print "Bail out!\\n";} } @modules
    );

    $t_files{'00-load.t'} = $header.<<"HERE";
plan tests => $nmodules;

BEGIN {
$use_lines
}

diag( "Testing $main_module \$${main_module}::VERSION, Perl \$], \$^X" );
HERE

    my $module_boilerplate_tests;
    $module_boilerplate_tests .=
      "  module_boilerplate_ok('".$self->_module_to_pm_file($_)."');\n" for @modules;

    my $boilerplate_tests = @modules + 2 + $[;
    $t_files{'boilerplate.t'} = $header.<<"HERE";
plan tests => $boilerplate_tests;

sub not_in_file_ok {
    my (\$filename, \%regex) = \@_;
    open( my \$fh, '<', \$filename )
        or die "couldn't open \$filename for reading: \$!";

    my \%violated;

    while (my \$line = <\$fh>) {
        while (my (\$desc, \$regex) = each \%regex) {
            if (\$line =~ \$regex) {
                push \@{\$violated{\$desc}||=[]}, \$.;
            }
        }
    }

    if (\%violated) {
        fail("\$filename contains boilerplate text");
        diag "\$_ appears on lines \@{\$violated{\$_}}" for keys \%violated;
    } else {
        pass("\$filename contains no boilerplate text");
    }
}

sub module_boilerplate_ok {
    my (\$module) = \@_;
    not_in_file_ok(\$module =>
        'the great new \$MODULENAME'   => qr/ - The great new /,
        'boilerplate description'     => qr/Quick summary of what the module/,
        'stub function definition'    => qr/function[12]/,
    );
}

TODO: {
  local \$TODO = "Need to replace the boilerplate text";

  not_in_file_ok(README =>
    "The README is used..."       => qr/The README is used/,
    "'version information here'"  => qr/to provide version information/,
  );

  not_in_file_ok(Changes =>
    "placeholder date/time"       => qr(Date/time)
  );

$module_boilerplate_tests

}

HERE

    return %t_files;
}

sub _create_t {
    my $self = shift;
    my $filename = shift;
    my $content = shift;

    my @dirparts = ( $self->{basedir}, 't' );
    my $tdir = File::Spec->catdir( @dirparts );
    if ( not -d $tdir ) {
        local @ARGV = $tdir;
        mkpath();
        $self->progress( "Created $tdir" );
    }

    my $fname = File::Spec->catfile( @dirparts, $filename );
    $self->create_file( $fname, $content );
    $self->progress( "Created $fname" );

    return "t/$filename";
}

=head2 create_MB_MANIFEST

This methods creates a MANIFEST file using Module::Build's methods.

=cut

sub create_MB_MANIFEST {
    my $self = shift;
    $self->create_EUMM_MANIFEST;
}

=head2 create_MI_MANIFEST

This method creates a MANIFEST file using Module::Install's methods.

Currently runs ExtUtils::MakeMaker's methods.

=cut

sub create_MI_MANIFEST {
    my $self = shift;
    $self->create_EUMM_MANIFEST;
}

=head2 create_EUMM_MANIFEST

This method creates a MANIFEST file using ExtUtils::MakeMaker's methods.

=cut

sub create_EUMM_MANIFEST {
    my $self     = shift;
    my $orig_dir = cwd();

    # create the MANIFEST in the correct path
    chdir $self->{'basedir'} || die "Can't reach basedir: $!\n";

    require ExtUtils::Manifest;
    $ExtUtils::Manifest::Quiet = 0;
    ExtUtils::Manifest::mkmanifest();

    # return to our original path, wherever it was
    chdir $orig_dir || die "Can't return to original dir: $!\n";
}

=head2 create_MANIFEST( $method )

This method creates the distribution's MANIFEST file.  It must be run last,
because all the other create_* functions have been returning the functions they
create.

It receives a method to run in order to create the MANIFEST file. That way it
can create a MANIFEST file according to the builder used.

=cut

sub create_MANIFEST {
    my ( $self, $manifest_method ) = @_;
    my $fname = File::Spec->catfile( $self->{basedir}, 'MANIFEST' );

    $self->$manifest_method();
    $self->filter_lines_in_file(
        $fname,
        qr/^t\/boilerplate\.t$/,
        qr/^ignore\.txt$/,
    );

    $self->progress( "Created $fname" );

    return 'MANIFEST';
}

=head2 get_builders( )

This methods gets the correct builder(s).

It is called by C<create_build>, and returns an arrayref with the builders.

=cut

sub get_builders {
    my $self = shift;

    # pass one: pull the builders out of $self->{builder}
    my @tmp =
        ref $self->{'builder'} eq 'ARRAY' ? @{ $self->{'builder'} }
                                          : $self->{'builder'};

    my @builders;
    my $COMMA = q{,};
    # pass two: expand comma-delimited builder lists
    foreach my $builder (@tmp) {
        push( @builders, split( $COMMA, $builder ) );
    }

    return \@builders;
}

=head2 create_build( )

This method creates the build file(s) and puts together some build
instructions.  The builders currently supported are:

ExtUtils::MakeMaker
Module::Build
Module::Install

=cut

sub create_build {
    my $self = shift;

    # get the builders
    my @builders    = @{ $self->get_builders };
    my $builder_set = Module::Starter::BuilderSet->new();

    # Remove mutually exclusive and unsupported builders
    @builders = $builder_set->check_compatibility( @builders );

    # compile some build instructions, create a list of files generated
    # by the builders' create_* methods, and call said methods

    my @build_instructions;
    my @files;
    my $manifest_method;

    foreach my $builder ( @builders ) {
        if ( !@build_instructions ) {
            push( @build_instructions,
                'To install this module, run the following commands:'
            );
        }
        else {
            push( @build_instructions,
                "Alternatively, to install with $builder, you can ".
                "use the following commands:"
            );
        }
        push( @files, $builder_set->file_for_builder($builder) );
        my @commands = $builder_set->instructions_for_builder($builder);
        push( @build_instructions, join("\n", map { "\t$_" } @commands) );

        my $build_method = $builder_set->method_for_builder($builder);
        $self->$build_method($self->{main_module});

        $manifest_method = $builder_set->manifest_method($builder);
    }

    return(
        files           => [ @files ],
        instructions    => join( "\n\n", @build_instructions ),
        manifest_method => $manifest_method,
    );
}


=head2 create_ignores()

This creates a text file for use as MANIFEST.SKIP, .cvsignore,
.gitignore, or whatever you use.

=cut

sub create_ignores {
    my $self  = shift;
    my $type  = $self->{ignores_type};
    my %names = (
        generic  => 'ignore.txt',
        cvs      => '.cvsignore',
        git      => '.gitignore',
        manifest => 'MANIFEST.SKIP',
    );

    my $create_file = sub {
        my $type  = shift;
        my $name  = $names{$type};
        my $fname = File::Spec->catfile( $self->{basedir}, $names{$type} );
        $self->create_file( $fname, $self->ignores_guts($type) );
        $self->progress( "Created $fname" );
    };

    if ( ref $type eq 'ARRAY' ) {
        foreach my $single_type ( @{$type} ) {
            $create_file->($single_type);
        }
    } elsif ( ! ref $type ) {
        $create_file->($type);
    }

    return; # Not a file that goes in the MANIFEST
}

=head2 ignores_guts()

Called by C<create_ignores>, this method returns the contents of the
ignore file.

=cut

sub ignores_guts {
    my ($self, $type) = @_;

    my $ms = $self->{manifest_skip} ? "MANIFEST\nMANIFEST.bak\n" : '';
    my $guts = {
        generic => $ms.<<"EOF",
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
pm_to_blib
$self->{distro}-*
$self->{distro}-*.tar.gz
EOF
        # make this more restrictive, since MANIFEST tends to be less noticable
        # (also, manifest supports REs.)
        manifest => <<'EOF',
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
    };
    $guts->{cvs} = $guts->{git} = $guts->{generic};
    
    return $guts->{$type};
}

=head1 HELPER METHODS

=head2 verbose

C<verbose> tells us whether we're in verbose mode.

=cut

sub verbose { return shift->{verbose} }

=head2 create_file( $fname, @content_lines )

Creates I<$fname>, dumps I<@content_lines> in it, and closes it.
Dies on any error.

=cut

sub create_file {
    my $self = shift;
    my $fname = shift;

    my @content = @_;
    open( my $fh, '>', $fname ) or confess "Can't create $fname: $!\n";
    print {$fh} @content;
    close $fh or die "Can't close $fname: $!\n";

    return;
}

=head2 progress( @list )

C<progress> prints the given progress message if we're in verbose mode.

=cut

sub progress {
    my $self = shift;
    print @_, "\n" if $self->verbose;

    return;
}

=head2 filter_lines_in_file( $filename, @compiled_regexes )

C<filter_lines_in_file> goes over a file and removes lines with the received
regexes.

For example, removing t/boilerplate.t in the MANIFEST.

=cut

sub filter_lines_in_file {
    my ( $self, $file, @regexes ) = @_;
    my @read_lines;
    open my $fh, '<', $file or die "Can't open file $file: $!\n";
    @read_lines = <$fh>;
    close $fh or die "Can't close file $file: $!\n";

    chomp @read_lines;

    open $fh, '>', $file or die "Can't open file $file: $!\n";
    foreach my $line (@read_lines) {
        my $found;

        foreach my $regex (@regexes) {
            if ( $line =~ $regex ) {
                $found++;
            }
        }

        $found or print {$fh} "$line\n";
    }
    close $fh or die "Can't close file $file: $!\n";
}

=head1 BUGS

Please report any bugs or feature requests to
C<bug-module-starter at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll automatically
be notified of progress on your bug as I make changes.

=head1 AUTHOR

Sawyer X, C<< <xsawyerx@cpan.org> >>

Andy Lester, C<< <andy@petdance.com> >>

C.J. Adams-Collier, C<< <cjac@colliertech.org> >>

=head1 Copyright & License

Copyright 2005-2009 Andy Lester and C.J. Adams-Collier, All Rights Reserved.

Copyright 2010 Sawyer X, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

Please note that these modules are not products of or supported by the
employers of the various contributors to the code.

=cut

sub _module_header {
    my $self = shift;
    my $module = shift;
    my $rtname = shift;
    my $content = <<"HERE";
package $module;

use $self->{minperl};
use strict;
use warnings FATAL => 'all';

\=head1 NAME

$module - The great new $module!

\=head1 VERSION

Version 0.01

\=cut

our \$VERSION = '0.01';
HERE
    return $content;
}

sub _module_bugs {
    my $self   = shift;
    my $module = shift;
    my $rtname = shift;

    my $bug_email = "bug-\L$self->{distro}\E at rt.cpan.org";
    my $bug_link  =
      "http://rt.cpan.org/NoAuth/ReportBug.html?Queue=$self->{distro}";

    my $content = <<"HERE";
\=head1 BUGS

Please report any bugs or feature requests to C<$bug_email>, or through
the web interface at L<$bug_link>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

HERE

    return $content;
}

sub _module_support {
    my $self   = shift;
    my $module = shift;
    my $rtname = shift;

    my $content = qq[
\=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc $module
];
    my @reference_links = _reference_links();

    return unless @reference_links;
    $content .= qq[

You can also look for information at:

\=over 4
];

    foreach my $ref (@reference_links) {
        my $title;
        my $link = sprintf($ref->{link}, $self->{distro});

        $title = "$ref->{nickname}: " if exists $ref->{nickname};
        $title .= $ref->{title};
        $content .= qq[
\=item * $title

L<$link>
];
    }
    $content .= qq[
\=back
];
    return $content;
}

sub _module_license {
    my $self = shift;

    my $module = shift;
    my $rtname = shift;

    my $license_blurb = $self->_license_blurb();
    my $year          = $self->_thisyear();

    my $content = qq[
\=head1 LICENSE AND COPYRIGHT

Copyright $year $self->{author}.

$license_blurb
];

    return $content;
}

sub module_guts {
    my $self = shift;
    my $module = shift;
    my $rtname = shift;

    # Sub-templates
    my $header  = $self->_module_header($module, $rtname);
    my $bugs    = $self->_module_bugs($module, $rtname);
    my $support = $self->_module_support($module, $rtname);
    my $license = $self->_module_license($module, $rtname);

    my $content = <<"HERE";
$header

\=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use $module;

    my \$foo = $module->new();
    ...

\=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

\=head1 SUBROUTINES/METHODS

\=head2 function1

\=cut

sub function1 {
}

\=head2 function2

\=cut

sub function2 {
}

\=head1 AUTHOR

$self->{author}, C<< <$self->{email_obfuscated}> >>

$bugs

$support

\=head1 ACKNOWLEDGEMENTS

$license

\=cut

1; # End of $module
HERE
    return $content;
}

1;

# vi:et:sw=4 ts=4
