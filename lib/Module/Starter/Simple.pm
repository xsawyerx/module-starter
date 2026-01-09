package Module::Starter::Simple;

use 5.008003;
use strict;
use warnings;

use Cwd 'cwd';
use File::Path qw( make_path );
use File::Spec ();
use Carp qw( carp confess croak );
use Module::Runtime qw( require_module );

use Module::Starter::BuilderSet;

=head1 NAME

Module::Starter::Simple - a simple, comprehensive Module::Starter plugin

=cut

our $VERSION = '1.82';

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

    if ( ( not @{ $self->{author} } ) && ( $^O ne 'MSWin32' ) ) {
        ( $self->{author} ) = split /,/, ( getpwuid $> )[6];
        $self->{author} = [ 
            exists $ENV{EMAIL} 
                ? "$self->{author} <$ENV{EMAIL}>" 
                : $self->{author} 
        ] if defined $self->{author};
    }

    croak "Must specify one or more authors\n" 
        unless defined $self->{author}
        && ref($self->{author}) eq 'ARRAY'
        && @{$self->{author}} > 0;

    croak "author strings must be in the format: 'Author Name <author-email\@domain.tld>'"
        if grep {
            $_ !~ /
                      \A
                      (?>
                          (?:           # Author
                              [^\s<>]+
                              \s+
                          )+
                      )
                      <[^<>]+>          # Email
                      \s*
                      \z
                  /x;
        } @{$self->{author}};
    
    $self->{license}      ||= 'artistic2';
    $self->{minperl}      ||= '5.008003';
    $self->{ignores_type} ||= ['generic'];
    $self->{manifest_skip} = !! grep { /manifest/ } @{ $self->{ignores_type} };
    
    $self->{license_record} = $self->_license_record();

    $self->{main_module} = $modules[0];
    if ( not defined $self->{distro} or not length $self->{distro} ) {
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
    push @files, $self->create_LICENSE if $self->{genlicense};

    $self->create_MANIFEST( $build_results{'manifest_method'} ) unless ( $self->{manifest_skip} );
    # TODO: put files to ignore in a more standard form?

    return @files;
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
        warn( "$self->{basedir} already exists.  ".
             "Will not overwrite files unless --force is used.\n"
            ) unless $self->{force};
    }

    CREATE_IT: {
        $self->progress( "Created $self->{basedir}" );

        make_path $self->{basedir};

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
    perl      => 'Perl_5',
    artistic  => 'Artistic_1_0',
    artistic2 => 'Artistic_2_0',
    mozilla   => 'Mozilla_1_1',
    mozilla2  => 'Mozilla_2_0',
    bsd       => 'BSD',
    freebsd   => 'FreeBSD',
    cc0       => 'CC0_1_0',
    gpl       => 'GPL_2',
    lgpl      => 'LGPL_2_1',
    gpl3      => 'GPL_3',
    lgpl3     => 'LGPL_3_0',
    agpl3     => 'AGPL_3',
    apache    => 'Apache_2_0',
    qpl       => 'QPL_1_0',
};

sub _license_record {
    my $self = shift;
    my $key = $LICENSES->{ $self->{license} };
    $key = $self->{license} unless defined $key;
    my $class = $key =~ m/::/ ? $key : "Software::License::$key";
    {
        local $@;
        undef $class unless eval { require_module $class; 1 } and $class->can('new');
    }
    unless (defined $class) {
        require Software::LicenseUtils;
        ($class) = Software::LicenseUtils->guess_license_from_meta_key($key);
        return undef unless defined $class;
    }
    my $author = join ',', @{$self->{author}};
    return $class->new( { holder => $author } );
}

sub _license_blurb {
    my $self = shift;

    my $record = $self->{license_record};
    my $license_blurb = defined($record) ?
        $record->notice :
        <<"EOT";
This software is Copyright (c) @{[ $self->_thisyear ]} by @{[ join ',', @{ $self->{author} } ]}.

This program is released under the following license:

  $self->{license}
EOT

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
            make_path $dir;
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
        link     => 'https://rt.cpan.org/NoAuth/Bugs.html?Dist=%s',
      },
      { title    => 'GitHub issue tracker',
        link     => 'https://github.com/%s/%s/issues',
        option   => 'github',
      },
      { title    => 'Search CPAN',
        link     => 'https://metacpan.org/release/%s',
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

    my $author = '[' . 
       join(',', map { "'" . s/'/\'/rg . "'" } @{$self->{author}}) 
       . ']';
    
    my $slname = $self->{license_record} ? $self->{license_record}->meta2_name : $self->{license};

    my $warnings = sprintf 'warnings%s;', ($self->{fatalize} ? " FATAL => 'all'" : '');

    my $meta_merge = $self->Makefile_PL_meta_merge;

    return <<"HERE";
use $self->{minperl};
use strict;
use $warnings
use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
    NAME             => '$main_module',
    AUTHOR           => $author,
    VERSION_FROM     => '$main_pm_file',
    ABSTRACT_FROM    => '$main_pm_file',
    LICENSE          => '$slname',
    MIN_PERL_VERSION => '$self->{minperl}',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
    },
    TEST_REQUIRES => {
        'Test::More' => '0',
    },
    PREREQ_PM => {
        #'ABC'              => '1.6',
        #'Foo::Bar::Module' => '5.0401',
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => '$self->{distro}-*' },
$meta_merge);

# Compatibility with old versions of ExtUtils::MakeMaker
unless (eval { ExtUtils::MakeMaker->VERSION('6.64'); 1 }) {
    my \$test_requires = delete \$WriteMakefileArgs{TEST_REQUIRES} || {};
    \@{\$WriteMakefileArgs{PREREQ_PM}}{keys %\$test_requires} = values %\$test_requires;
}

unless (eval { ExtUtils::MakeMaker->VERSION('6.55_03'); 1 }) {
    my \$build_requires = delete \$WriteMakefileArgs{BUILD_REQUIRES} || {};
    \@{\$WriteMakefileArgs{PREREQ_PM}}{keys %\$build_requires} = values %\$build_requires;
}

delete \$WriteMakefileArgs{CONFIGURE_REQUIRES}
    unless eval { ExtUtils::MakeMaker->VERSION('6.52'); 1 };
delete \$WriteMakefileArgs{MIN_PERL_VERSION}
    unless eval { ExtUtils::MakeMaker->VERSION('6.48'); 1 };
delete \$WriteMakefileArgs{LICENSE}
    unless eval { ExtUtils::MakeMaker->VERSION('6.31'); 1 };

WriteMakefile(%WriteMakefileArgs);
HERE

}

=head2 Makefile_PL_meta_merge

Method called by Makefile_PL_guts. Returns the C<META_MERGE> section - currently
only if the option C<github> is set, in which case the C<< resources => repository >>
entry is created.

=cut

sub Makefile_PL_meta_merge {
    my $self = shift;
    return '' unless defined $self->{github};

    my $username   = $self->{github};
    my $repository = $self->{distro};

    return <<"HERE";
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/$username/$repository.git',
                web  => 'https://github.com/$username/$repository',
            },
            bugtracker => {
                web => 'https://github.com/$username/$repository/issues',
            },
        },
    },
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

    my $author = join ',', @{$self->{author}};
    $author =~ s/'/\'/g;

    my $license_url = $self->{license_record} ? $self->{license_record}->url : '';

    # if there is more than one author, select the first one as
    # the repository owner
    my ($repo_author) = (split /\s*\</, $self->{author}->[0])[0];

    my $warnings = sprintf 'warnings%s;', ($self->{fatalize} ? " FATAL => 'all'" : '');

    return <<"HERE";
use $self->{minperl};
use strict;
use $warnings
use inc::Module::Install;

name     '$self->{distro}';
all_from '$main_pm_file';
author   q{$author};
license  '$self->{license}';

perl_version '$self->{minperl}';

tests_recursive('t');

resources (
   #homepage   => 'http://yourwebsitehere.com',
   #IRC        => 'irc://irc.perl.org/#$self->{distro}',
   license    => '$license_url',
   #repository => 'git://github.com/$repo_author/$self->{distro}.git',
   #repository => 'https://bitbucket.org/$repo_author/$self->{distro}',
   bugtracker => 'https://rt.cpan.org/NoAuth/Bugs.html?Dist=$self->{distro}',
);

configure_requires (
   'Module::Install' => '0',
);

test_requires (
   'Test::More' => '0',
);

requires (
   #'ABC'              => '1.6',
   #'Foo::Bar::Module' => '5.0401',
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

    my $author = '[' . 
       join(',', map { "'" . s/'/\'/rg . "'" } @{$self->{author}}) 
       . ']';

    my $slname = $self->{license_record} ? $self->{license_record}->meta2_name : $self->{license};
    
    my $warnings = sprintf 'warnings%s;', ($self->{fatalize} ? " FATAL => 'all'" : '');

    my $meta_merge = $self->Build_PL_meta_merge;

    return <<"HERE";
use $self->{minperl};
use strict;
use $warnings
use Module::Build;
Module::Build->VERSION('0.4004');

my \$builder = Module::Build->new(
    module_name         => '$main_module',
    license             => '$slname',
    dist_author         => $author,
    dist_version_from   => '$main_pm_file',
    release_status      => 'stable',
    configure_requires => {
        'Module::Build' => '0.4004',
    },
    test_requires => {
        'Test::More' => '0',
    },
    requires => {
        #'ABC'              => '1.6',
        #'Foo::Bar::Module' => '5.0401',
    },
    add_to_cleanup     => [ '$self->{distro}-*' ],
$meta_merge);

\$builder->create_build_script();
HERE

}

=head2 Build_PL_meta_merge

Method called by Build_PL_guts. Returns the C<meta_merge> section - currently
only if the option C<github> is set, in which case the C<< resources => repository >>
entry is created.

=cut

sub Build_PL_meta_merge {
    my $self = shift;
    return '' unless defined $self->{github};

    my $username   = $self->{github};
    my $repository = $self->{distro};

    return <<"HERE";
    meta_merge => {
        resources => {
            repository => 'https://github.com/$username/$repository',
            bugtracker => 'https://github.com/$username/$repository/issues',
        },
    },
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

=head2 create_LICENSE

This method creates the distribution's LICENSE file.

=cut

sub create_LICENSE {
    my $self = shift;
    
    my $record = $self->{license_record} || return ();
    my $fname = File::Spec->catfile( $self->{basedir}, 'LICENSE' );
    $self->create_file( $fname, $record->license );
    $self->progress( "Created $fname" );
    
    return 'LICENSE';
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
        next if $ref->{option} && !$self->{$ref->{option}};

        my $title;
        $title = "$ref->{nickname}, " if exists $ref->{nickname};
        $title .= $ref->{title};
        my $link  = sprintf($ref->{link}, $ref->{option} ? $self->{$ref->{option}} : (), $self->{distro});

        $content .= qq[
    $title
        $link
];
    }

    return $content;
}

sub _README_license {
    my $self = shift;

    my $license_blurb = $self->_license_blurb();
return <<"HERE";
LICENSE AND COPYRIGHT

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

    my %t_files  = $self->t_guts(@modules);
    my %xt_files = $self->xt_guts(@modules);

    my @files;
    push @files, map { $self->_create_t('t',  $_, $t_files{$_}) }  keys %t_files;
    push @files, map { $self->_create_t('xt', $_, $xt_files{$_}) } keys %xt_files;

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
    my $warnings = sprintf 'warnings%s;', ($self->{fatalize} ? " FATAL => 'all'" : '');

    my $header = <<"EOH";
#!perl
use $minperl;
use strict;
use $warnings
use Test::More;

EOH
    
    $t_files{'pod.t'} = $header.<<'HERE';
unless ( $ENV{RELEASE_TESTING} ) {
    plan( skip_all => "Author tests not required for installation" );
}

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
unless ( $ENV{RELEASE_TESTING} ) {
    plan( skip_all => "Author tests not required for installation" );
}

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

    return %t_files;
}

=head2 xt_guts( @modules )

This method is called by create_t, and returns a description of the author
only *.t files to be created in the xt directory.

The return value is a hash of test files to create.  Each key is a filename and
each value is the contents of that file.

=cut

sub xt_guts {
    my $self = shift;
    my @modules = @_;

    my %xt_files;
    my $minperl = $self->{minperl};
    my $warnings = sprintf 'warnings%s;', ($self->{fatalize} ? " FATAL => 'all'" : '');

    my $header = <<"EOH";
#!perl
use $minperl;
use strict;
use $warnings
use Test::More;

EOH

    my $module_boilerplate_tests;
    $module_boilerplate_tests .=
      "  module_boilerplate_ok('".$self->_module_to_pm_file($_)."');\n" for @modules;

    my $boilerplate_tests = @modules + 2;
    $xt_files{'boilerplate.t'} = $header.<<"HERE";
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

    return %xt_files;
}

sub _create_t {
    my $self = shift;
    my $directory = shift;  # 't' or 'xt'
    my $filename = shift;
    my $content = shift;

    my @dirparts = ( $self->{basedir}, $directory );
    my $tdir = File::Spec->catdir( @dirparts );
    if ( not -d $tdir ) {
        make_path $tdir;
        $self->progress( "Created $tdir" );
    }

    my $fname = File::Spec->catfile( @dirparts, $filename );
    $self->create_file( $fname, $content );
    $self->progress( "Created $fname" );

    return join('/', $directory, $filename );
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
        qr/^xt\/boilerplate\.t$/,
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
        hg       => '.hgignore',
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
        # make this more restrictive, since MANIFEST tends to be less noticeable
        # (also, manifest supports REs.)
        manifest => <<'EOF',
# Top-level filter (only include the following...)
^(?!(?:script|examples|lib|inc|t|xt|maint)/|(?:(?:Makefile|Build)\.PL|README|LICENSE|MANIFEST|Changes|META\.(?:yml|json))$)

# Avoid version control files.
\bRCS\b
\bCVS\b
,v$
\B\.svn\b
\b_darcs\b
# (.git or .hg only in top-level, hence it's blocked above)

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
    $guts->{hg} = $guts->{cvs} = $guts->{git} = $guts->{generic};
    
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

    if ( -f $fname ) {
        if ( !$self->{'force'} ) {
            warn "Will not overwrite '$fname' (--force option not enabled)";
            return;
        }
    }

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

Please report any bugs or feature requests to the bugtracker for this project
on GitHub at: L<https://github.com/xsawyerx/module-starter/issues>. I will be
notified, and then you'll automatically be notified of progress on your bug
as I make changes.

=head1 AUTHOR

Dan Book, L<< <dbook@cpan.org> >>

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
    my $warnings = sprintf 'warnings%s;', ($self->{fatalize} ? " FATAL => 'all'" : '');

    my $content = <<"HERE";
package $module;

use $self->{minperl};
use strict;
use $warnings

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
      "https://rt.cpan.org/NoAuth/ReportBug.html?Queue=$self->{distro}";

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

    return undef unless @reference_links;
    $content .= qq[

You can also look for information at:

\=over 4
];

    foreach my $ref (@reference_links) {
        next if $ref->{option} && !$self->{$ref->{option}};

        my $title;
        my $link = sprintf($ref->{link}, $ref->{option} ? $self->{$ref->{option}} : (), $self->{distro});

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
    my $content = qq[
\=head1 LICENSE AND COPYRIGHT

$license_blurb
];

    return $content;
}

sub module_guts {
    my $self = shift;
    my $module = shift;
    my $rtname = shift;

    # Sub-templates
    my $header        = $self->_module_header($module, $rtname);
    my $bugs          = $self->_module_bugs($module, $rtname);
    my $support       = $self->_module_support($module, $rtname);
    my $license       = $self->_module_license($module, $rtname);
    my $author_string = join ',', @{$self->{author}};
    
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

$author_string

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
