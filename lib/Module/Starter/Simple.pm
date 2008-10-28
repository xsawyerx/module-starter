package Module::Starter::Simple;
# vi:et:sw=4 ts=4

use strict;
use warnings;

use ExtUtils::Command qw( rm_rf mkpath touch );
use File::Spec ();
use Carp qw( carp confess croak );

use Module::Starter::BuilderSet;

=head1 NAME

Module::Starter::Simple - a simple, comprehensive Module::Starter plugin

=head1 VERSION

Version 1.50

=cut

our $VERSION = '1.50';

=head1 SYNOPSIS

    use Module::Starter qw(Module::Starter::Simple);

    Module::Starter->create_distro(%args);

=head1 DESCRIPTION

Module::Starter::Simple is a plugin for Module::Starter that will perform all
the work needed to create a distribution.  Given the parameters detailed in
L<Module::Starter>, it will create content, create directories, and populate
the directories with the required files.

=head1 CLASS METHODS

=head2 C<< create_distro(%args) >>

This method works as advertised in L<Module::Starter>.

=cut

sub create_distro {
    my $class = shift;

    my $self = $class->new( @_ );

    my $modules = $self->{modules} || [];
    my @modules = map { split /,/ } @{$modules};
    croak "No modules specified.\n" unless @modules;
    for (@modules) {
        croak "Invalid module name: $_" unless /\A[a-z_]\w*(?:::[\w]+)*\Z/i;
    }

    croak "Must specify an author\n" unless $self->{author};
    croak "Must specify an email address\n" unless $self->{email};
    ($self->{email_obfuscated} = $self->{email}) =~ s/@/ at /;

    $self->{license} ||= 'perl';

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
    push @files, $self->create_cvsignore;
    my %build_results = $self->create_build();
    push(@files, @{ $build_results{files} } );

    push @files, $self->create_Changes;
    push @files, $self->create_README( $build_results{instructions} );
    push @files, 'MANIFEST';
    $self->create_MANIFEST( grep { $_ ne 't/boilerplate.t' } @files );

    return;
}

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
internally by the ephemperal objects created during the execution of the class
method C<create_distro> above.

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

sub _license_blurb {
    my $self = shift;
    my $license_blurb;

    if ($self->{license} eq 'perl') {
        $license_blurb = <<'EOT';
This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
EOT
    }
    else {
        $license_blurb = <<"EOT";
This program is released under the following license: $self->{license}
EOT
    }
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
  return
    ( { nickname => 'RT',
        title    => 'CPAN\'s request tracker',
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

    return <<"HERE";
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => '$main_module',
    AUTHOR              => '$author',
    VERSION_FROM        => '$main_pm_file',
    ABSTRACT_FROM       => '$main_pm_file',
    (\$ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> '$self->{license}')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => '$self->{distro}-*' },
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

    (my $author = "$self->{author} <$self->{email}>") =~ s/'/\'/g;

    return <<"HERE";
use inc::Module::Install;

name     '$self->{distro}';
all_from '$main_pm_file';
author   '$author';
license  '$self->{license}';

build_requires 'Test::More';

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

    return <<"HERE";
use strict;
use warnings;
use Module::Build;

my \$builder = Module::Build->new(
    module_name         => '$main_module',
    license             => '$self->{license}',
    dist_author         => '$author',
    dist_version_from   => '$main_pm_file',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ '$self->{distro}-*' ],
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
COPYRIGHT AND LICENCE

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

    $t_files{'pod.t'} = <<'HERE';
#!perl -T

use strict;
use warnings;
use Test::More;

# Ensure a recent version of Test::Pod
my $min_tp = 1.22;
eval "use Test::Pod $min_tp";
plan skip_all => "Test::Pod $min_tp required for testing POD" if $@;

all_pod_files_ok();
HERE

    $t_files{'pod-coverage.t'} = <<'HERE';
use strict;
use warnings;
use Test::More;

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
    my $use_lines = join( "\n", map { "\tuse_ok( '$_' );" } @modules );

    $t_files{'00-load.t'} = <<"HERE";
#!perl -T

use Test::More tests => $nmodules;

BEGIN {
$use_lines
}

diag( "Testing $main_module \$${main_module}::VERSION, Perl \$], \$^X" );
HERE

    my $module_boilerplate_tests;
    $module_boilerplate_tests .=
      "  module_boilerplate_ok('$self->{module_file}{$_}');\n" for @modules;

    my $boilerplate_tests = @modules + 2 + $[;
    $t_files{'boilerplate.t'} = <<"HERE";
#!perl -T

use strict;
use warnings;
use Test::More tests => $boilerplate_tests;

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

=head2 create_MANIFEST( @files )

This method creates the distribution's MANIFEST file.  It must be run last,
because all the other create_* functions have been returning the functions they
create.

=cut

sub create_MANIFEST {
    my $self = shift;
    my @files = @_;

    my $fname = File::Spec->catfile( $self->{basedir}, 'MANIFEST' );
    $self->create_file( $fname, $self->MANIFEST_guts(@files) );
    $self->progress( "Created $fname" );

    return 'MANIFEST';
}

=head2 MANIFEST_guts( @files )

This method is called by C<create_MANIFEST>, and returns content for the
MANIFEST file.

=cut

sub MANIFEST_guts {
    my $self = shift;
    my @files = sort @_;

    return join( "\n", @files, '' );
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

  # pass one: pull the builders out of $self->{builder}
  my @tmp =
    ref $self->{builder} eq 'ARRAY' ? @{$self->{builder}} : $self->{builder};

  my @builders;
  my $COMMA = q{,};
  # pass two: expand comma-delimited builder lists
  foreach my $builder (@tmp) {
    push( @builders, split($COMMA, $builder) );
  }

  my $builder_set = Module::Starter::BuilderSet->new();

  # Remove mutually exclusive and unsupported builders
  @builders = $builder_set->check_compatibility( @builders );

  # compile some build instructions, create a list of files generated
  # by the builders' create_* methods, and call said methods

  my @build_instructions;
  my @files;

  foreach my $builder ( @builders ) {
    if ( !@build_instructions ) {
      push( @build_instructions,
            'To install this module, run the following commands:'
          );
    } else {
      push( @build_instructions,
            "Alternatively, to install with $builder, you can ".
            "use the following commands:"
          );
    }
    push( @files, $builder_set->file_for_builder($builder) );
    my @commands = $builder_set->instructions_for_builder($builder);
    push( @build_instructions, join("\n", map { "\t$_" } @commands) );

    my $build_method = $builder_set->method_for_builder($builder);
    $self->$build_method($self->{main_module})
  }

  return( files        => [ @files ],
          instructions => join( "\n\n", @build_instructions ),
        );
}

=head2 create_cvsignore( )

This creates a .cvsignore file in the distribution's directory so that your CVS
knows to ignore certain files.

=cut

sub create_cvsignore {
    my $self = shift;

    my $fname = File::Spec->catfile( $self->{basedir}, '.cvsignore' );
    $self->create_file( $fname, $self->cvsignore_guts() );
    $self->progress( "Created $fname" );

    return; # Not a file that goes in the MANIFEST
}

=head2 cvsignore_guts

Called by C<create_cvsignore>, this method returns the contents of the
cvsignore file.

=cut

sub cvsignore_guts {
    my $self = shift;

    return <<"HERE";
blib*
Makefile
Makefile.old
Build
_build*
pm_to_blib*
*.tar.gz
.lwpcookies
$self->{distro}-*
cover_db
HERE
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

=head1 BUGS

Please report any bugs or feature requests to
C<bug-module-starter at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll automatically
be notified of progress on your bug as I make changes.

=head1 AUTHOR

Andy Lester, C<< <andy@petdance.com> >>

C.J. Adams-Collier, C<< <cjac@colliertech.org> >>

=head1 Copyright & License

Copyright 2005-2007 Andy Lester and C.J. Adams-Collier, All Rights Reserved.

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

use warnings;
use strict;

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

    foreach my $ref (@reference_links){
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
\=head1 COPYRIGHT & LICENSE

Copyright $year $self->{author}, all rights reserved.

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

\=head1 FUNCTIONS

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
