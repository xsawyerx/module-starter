package Module::Starter::TestPlugin; # Module::Starter::PBP
use base 'Module::Starter::Simple';

use version; $VERSION = qv('0.0.3');

use warnings;
use strict;
use Carp;

sub module_guts {
    my $self = shift;
    my %context = (
        'MODULE NAME' => shift,
        'RT NAME'     => shift,
        'DATE'        => scalar localtime,
        'YEAR'        => $self->_thisyear(),
    );

    return $self->_load_and_expand_template('Module.pm', \%context);
}


sub Makefile_PL_guts {
    my $self = shift;
    my %context = (
        'MAIN MODULE'  => shift,
        'MAIN PM FILE' => shift,
        'DATE'         => scalar localtime,
        'YEAR'         => $self->_thisyear(),
    );

    return $self->_load_and_expand_template('Makefile.PL', \%context);
}

sub Build_PL_guts {
    my $self = shift;
    my %context = (
        'MAIN MODULE'  => shift,
        'MAIN PM FILE' => shift,
        'DATE'         => scalar localtime,
        'YEAR'         => $self->_thisyear(),
    );

    return $self->_load_and_expand_template('Build.PL', \%context);
}

sub Changes_guts {
    my $self = shift;

    my %context = (
        'DATE'         => scalar localtime,
        'YEAR'         => $self->_thisyear(),
    );

    return $self->_load_and_expand_template('Changes', \%context);
}

sub README_guts {
    my $self = shift;

    my %context = (
        'BUILD INSTRUCTIONS' => shift,
        'DATE'               => scalar localtime,
        'YEAR'               => $self->_thisyear(),
    );

    return $self->_load_and_expand_template('README', \%context);
}

sub t_guts {
    my $self = shift;
    my @modules = @_;
    my %context = (
        'DATE'               => scalar localtime,
        'YEAR'               => $self->_thisyear(),
    );

    my %t_files;
    for my $test_file ( map { s{\A .*/t/}{}xms; $_; }
                            glob "$self->{template_dir}/t/*" ) {
        $t_files{$test_file}
            = $self->_load_and_expand_template("t/$test_file", \%context);
    }

    my $nmodules = @modules;
    my $main_module = $modules[0];
    my $use_lines = join( "\n", map { "use_ok( '$_' );" } @modules );

    $t_files{'00-load.t'} = <<"END_LOAD";
use Test::More tests => $nmodules;

BEGIN {
$use_lines
}

diag( "Testing $main_module \$${main_module}::VERSION" );
END_LOAD

    return %t_files;
}

sub _load_and_expand_template {
    my ($self, $rel_file_path, $context_ref) = @_;

    @{$context_ref}{map {uc} keys %$self} = values %$self;

    die "Can't find directory that holds Module::Starter::PBP templates\n",
        "(no 'template_dir: <directory path>' in config file)\n"
        if not defined $self->{template_dir};

    die "Can't access Module::Starter::PBP template directory\n",
        "(perhaps 'template_dir: $self->{template_dir}' is wrong in config file?)\n"
        if not -d $self->{template_dir};

    my $abs_file_path = "$self->{template_dir}/$rel_file_path";

    die "The Module::Starter::PBP template: $rel_file_path\n",
        "isn't in the template directory ($self->{template_dir})\n\n"
        if not -e $abs_file_path;

    die "The Module::Starter::PBP template: $rel_file_path\n",
        "isn't readable in the template directory ($self->{template_dir})\n\n"
        if not -r $abs_file_path;

    open my $fh, '<', $abs_file_path or croak $!;
    local $/;
    my $text = <$fh>;

    $text =~ s{<([A-Z ]+)>}
              { $context_ref->{$1}
                || die "Unknown placeholder <$1> in $rel_file_path\n"
              }xmseg;

    return $text;
}

sub import {
    my $class = shift;
    my ($setup, @other_args) = @_;

    # If this is not a setup request,
    # refer the import request up the hierarchy...
    if (@other_args || !$setup || $setup ne 'setup') {
        return $class->SUPER::import(@_);
    }

    # Otherwise, gather the necessary tools...
    use ExtUtils::Command qw( mkpath );
    use File::Spec;
    local $| = 1;

    # Locate the home directory...
    if (!defined $ENV{HOME}) {
        print 'Please enter the full path of your home directory: ';
        $ENV{HOME} = <>;
        chomp $ENV{HOME};
        croak 'Not a valid directory. Aborting.'
            if !-d $ENV{HOME};
    }

    # Create the directories...
    my $template_dir
        = File::Spec->catdir( $ENV{HOME}, '.module-starter', 'PBP' );
    if ( not -d $template_dir ) {
        print {*STDERR} "Creating $template_dir...";
        local @ARGV = $template_dir;
        mkpath;
        print {*STDERR} "done.\n";
    }

    my $template_test_dir
        = File::Spec->catdir( $ENV{HOME}, '.module-starter', 'PBP', 't' );
    if ( not -d $template_test_dir ) {
        print {*STDERR} "Creating $template_test_dir...";
        local @ARGV = $template_test_dir;
        mkpath;
        print {*STDERR} "done.\n";
    }

    # Create or update the config file (making a backup, of course)...
    my $config_file
        = File::Spec->catfile( $ENV{HOME}, '.module-starter', 'config' );

    my @config_info;

    if ( -e $config_file ) {
        print {*STDERR} "Backing up $config_file...";
        my $backup
            = File::Spec->catfile( $ENV{HOME}, '.module-starter', 'config.bak' );
        rename($config_file, $backup);
        print {*STDERR} "done.\n";

        print {*STDERR} "Updating $config_file...";
        open my $fh, '<', $backup or die "$config_file: $!\n";
        @config_info
            = grep { not /\A (?: template_dir | plugins ) : /xms } <$fh>;
        close $fh or die "$config_file: $!\n";
    }
    else {
        print {*STDERR} "Creating $config_file...\n";

        my $author = _prompt_for('your full name');
        my $email  = _prompt_for('an email address');

        @config_info = (
            "author:  $author\n",
            "email:   $email\n",
            "builder: ExtUtils::MakeMaker Module::Build\n",
        );

        print {*STDERR} "Writing $config_file...\n";
    }

    push @config_info, (
        "plugins: Module::Starter::PBP\n",
        "template_dir: $template_dir\n",
    );

    open my $fh, '>', $config_file  or die "$config_file: $!\n";
    print {$fh} @config_info        or die "$config_file: $!\n";
    close $fh                       or die "$config_file: $!\n";
    print {*STDERR} "done.\n";

    print {*STDERR} "Installing templates...\n";
    # Then install the various files...
    my @files = (
        ['Build.PL'],
        ['Makefile.PL'],
        ['README'],
        ['Changes'],
        ['Module.pm'],
        ['t', 'pod-coverage.t'],
        ['t', 'pod.t'],
        ['t', 'perlcritic.t'],
    );

    my %contents_of = do { local $/; "", split /_____\[ (\S+) \]_+\n/, <DATA> };
    for (values %contents_of) {
        s/^!=([a-z])/=$1/gxms;
    }

    for my $ref_path ( @files ) {
        my $abs_path
            = File::Spec->catfile( $ENV{HOME}, '.module-starter', 'PBP', @{$ref_path} );
        print {*STDERR} "\t$abs_path...";
        open my $fh, '>', $abs_path                or die "$abs_path: $!\n";
        print {$fh} $contents_of{$ref_path->[-1]}  or die "$abs_path: $!\n";
        close $fh                                  or die "$abs_path: $!\n";
        print {*STDERR} "done\n";
    }
    print {*STDERR} "Installation complete.\n";

    exit;
}

sub _prompt_for {
    my ($requested_info) = @_;
    my $response;
    RESPONSE: while (1) {
        print "Please enter $requested_info: ";
        $response = <>;
        if (not defined $response) {
            warn "\n[Installation cancelled]\n";
            exit;
        }
        $response =~ s/\A \s+ | \s+ \Z//gxms;
        last RESPONSE if $response =~ /\S/;
    }
    return $response;
}


1; # Magic true value required at end of module

=pod

=head1 NAME

Module::Starter::PBP - Create a module as recommended in "Perl Best Practices"


=head1 VERSION

This document describes Module::Starter::PBP version 0.0.3


=head1 SYNOPSIS

    # In your  ~/.module-starter/config file...

    author:  <Your Name>
    email:   <your@email.addr>
    plugins: Module::Starter::PBP
    template_dir: </some/absolute/path/name>


    # Then on the command-line...

    > module-starter --module=Your::New::Module


    # Or, if you're lazy and happy to go with
    # the recommendations in "Perl Best Practices"...

    > perl -MModule::Starter::PBP=setup
  
  
=head1 DESCRIPTION

This module implements a simple approach to creating modules and their support
files, based on the Module::Starter approach. Module::Starter needs to be
installed before this module can be used.

When used as a Module::Starter plugin, this module allows you to specify a
simple directory of templates which are filled in with module-specific
information, and thereafter form the basis of your new module.

The default templates that this module initially provides are based on
the recommendations in the book "Perl Best Practices".


=head1 INTERFACE 

Thsi module simply acts as a plugin for Module::Starter. So it uses the same
command-line interface as that module.

The template files it is to use are specified in your Module::Starter
C<config> file, by adding a C<template_dir> configuration variable that
gives the full path name of the directory in which you want to put
the templates.

The easiest way to set up this C<config> file, the associated directory, and
the necessary template files is to type:

    > perl -MModule::Starter::PBP=setup

on the command line. You will then be asked for your name, email address, and
the full path name of the directory where you want to keep the templates,
after which they will be created and installed.

Then you can create a new module by typing:

    > module-starter --module=Your::New::Module


=head2 Template format

The templates are plain files named:

        Build.PL
        Makefile.PL
        README
        Changes
        Module.pm
        t/whatever_you_like.t

The C<Module.pm> file is the template for the C<.pm> file for your module. Any
files in the C<t/> subdirectory become the templates for the testing files of
your module. All the remaining files are templates for the ditribution files
of the same names.

In those files, the following placeholders are replaced by the appropriate
information specific to the file:

=over

=item <AUTHOR>

The nominated author. Taken from the C<author> setting in
your Module::Starter C<config> file.

=item <BUILD INSTRUCTIONS>

Makefile or Module::Build instructions. Computed automatically according to
the C<builder> setting in your Module::Starter C<config> file.

=item <DATE>

The current date (as returned by C<localtime>). Computed automagically

=item <DISTRO>

The name of the complete module distribution. Computed automatically from the
name of the module.

=item <EMAIL>

Where to send feedback. Taken from the C<email> setting in
your Module::Starter C<config> file.

=item <LICENSE>

The licence under which the module is released. Taken from the C<license>
setting in your Module::Starter C<config> file.

=item <MAIN MODULE>

The name of the main module of the distribution.

=item <MAIN PM FILE>

The name of the C<.pm> file for the main module.

=item <MODULE NAME>

The name of the current module being created within the distribution.

=item <RT NAME>

The name to use for bug reports to the RT system.
That is:

    Please report any bugs or feature requests to
    bug-<RT NAME>@rt.cpan.org>

=item <YEAR>

The current year. Computed automatically

=back


=head1 DIAGNOSTICS

=over

=item C<< Can't find directory that holds Module::Starter::PBP templates >>

You did not tell Module::Starter::PBP where your templates are stored.
You need a 'template_dir' specification. Typically this would go in
your ~/.module-starter/config file. Something like:

    template_dir: /users/you/.module-starter/Templates


=item C<< Can't access Module::Starter::PBP template directory >>

You specified a 'template_dir', but the path didn't lead to a readable
directory.


=item C<< The template: %s isn't in the template directory (%s) >>

One of the required templates:

was missing from the template directory you specified.


=item C<< The template: %s isn't readable in the template directory (%s) >>

One of the templates in the template directory you specified was not readable.


=item C<< Unknown placeholder <%s> in %s >>

One of the templates in the template directory contained a replacement item
that wasn't a known piece of information.

=back


=head1 CONFIGURATION AND ENVIRONMENT

See the documentation for C<Module::Starter> and C<module-starter>.


=head1 DEPENDENCIES

Requires the C<Module::Starter> module.


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-module-starter-pbp@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Damian Conway  C<< <DCONWAY@cpan.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2005, Damian Conway C<< <DCONWAY@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut



__DATA__

_____[ Build.PL ]________________________________________________
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => '<MAIN MODULE>',
    license             => '<LICENSE>',
    dist_author         => '<AUTHOR> <<EMAIL>>',
    dist_version_from   => '<MAIN PM FILE>',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
    },
    add_to_cleanup      => [ '<DISTRO>-*' ],
);

$builder->create_build_script();
_____[ Makefile.PL ]_____________________________________________
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => '<MAIN MODULE>',
    AUTHOR              => '<AUTHOR> <<EMAIL>>',
    VERSION_FROM        => '<MAIN PM FILE>',
    ABSTRACT_FROM       => '<MAIN PM FILE>',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => '<DISTRO>-*' },
);
_____[ README ]__________________________________________________
<DISTRO> version 0.0.1

[ REPLACE THIS...

  The README is used to introduce the module and provide instructions on
  how to install the module, any machine dependencies it may have (for
  example C compilers and installed libraries) and any other information
  that should be understood before the module is installed.

  A README file is required for CPAN modules since CPAN extracts the
  README file from a module distribution so that people browsing the
  archive can use it get an idea of the modules uses. It is usually a
  good idea to provide version information here so that people can
  decide whether fixes for the module are worth downloading.
]


INSTALLATION

<BUILD INSTRUCTIONS>


DEPENDENCIES

None.


COPYRIGHT AND LICENCE

Copyright (C) <YEAR>, <AUTHOR>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
_____[ Changes ]_________________________________________________
Revision history for <DISTRO>

0.0.1  <DATE>
       Initial release.

_____[ Module.pm ]_______________________________________________
package <MODULE NAME>;

use warnings;
use strict;
use Carp;

use version; $VERSION = qv('0.0.3');

# Other recommended modules (uncomment to use):
#  use IO::Prompt;
#  use Perl6::Export;
#  use Perl6::Slurp;
#  use Perl6::Say;


# Module implementation here


1; # Magic true value required at end of module
__END__

!=head1 NAME

<MODULE NAME> - [One line description of module's purpose here]


!=head1 VERSION

This document describes <MODULE NAME> version 0.0.1


!=head1 SYNOPSIS

    use <MODULE NAME>;

!=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
!=head1 DESCRIPTION

!=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


!=head1 INTERFACE 

!=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


!=head1 DIAGNOSTICS

!=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

!=over

!=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

!=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

!=back


!=head1 CONFIGURATION AND ENVIRONMENT

!=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
<MODULE NAME> requires no configuration files or environment variables.


!=head1 DEPENDENCIES

!=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


!=head1 INCOMPATIBILITIES

!=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


!=head1 BUGS AND LIMITATIONS

!=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-<RT NAME>@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


!=head1 AUTHOR

<AUTHOR>  C<< <<EMAIL>> >>


!=head1 LICENCE AND COPYRIGHT

Copyright (c) <YEAR>, <AUTHOR> C<< <<EMAIL>> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


!=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
_____[ pod-coverage.t ]__________________________________________
#!perl -T

use Test::More;
eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;
all_pod_coverage_ok();
_____[ pod.t ]___________________________________________________
#!perl -T

use Test::More;
eval "use Test::Pod 1.14";
plan skip_all => "Test::Pod 1.14 required for testing POD" if $@;
all_pod_files_ok();
_____[ perlcritic.t ]___________________________________________________
#!perl

if (!require Test::Perl::Critic) {
    Test::More::plan(
        skip_all => "Test::Perl::Critic required for testing PBP compliance"
    );
}

Test::Perl::Critic::all_critic_ok();
