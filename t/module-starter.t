#!perl -T

=head1 DESCRIPTION

module-starter.t is a collection of tests to ensure that the
C<module-starter> script behaves correctly.

We test...

=over 4

=item * options processing

=item * correct file layout of generated package

=item * successful make and test runs of generated package

=back

=cut

use strict;
use warnings;

use Test::More;
plan skip_all => "these tests must be completely rewritten";

use English '-no_match_vars';

use File::Spec;
use File::Temp qw/ tempdir /;
use File::Find;

use Carp qw/ carp /;

use Module::Starter::BuilderSet;

# Since we're making system calls from this test, we have to be extra
# paranoid.

# Clean up the environment
my $old_path = $ENV{PATH};

$ENV{PATH} = "";
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

my $test_name        = __FILE__;

(my $dist_dir)       =
  (File::Spec->rel2abs($test_name) =~ m{^(.+)$test_name$});

# $dest_dir may not have had the taint adequately scrubbed from it, so
# we'll check to see if it contains some of the files we expect it to

my $test_libpath     = catfile($dist_dir, 't', 'lib');
my $test_filename    = catfile($dist_dir, $test_name);
my $changes_filename = catfile($dist_dir, 'Changes');
my $test_dir         = catfile($dist_dir, 't');
my $module_starter   = catfile($dist_dir, 'blib', 'script', 'module-starter');
my $template_dir     = catfile($dist_dir, 't', 'data', 'templates');
my $config_dir       = catfile($dist_dir, 't', 'data');
my $config_file      = catfile($config_dir, 'config');

my $temp_dir         = tempdir( CLEANUP => 1 );

my $author           = 'C.J. Adams-Collier';
my $email            = 'cjac@colliertech.org';

my %options =
  ( author => $author,
    email  => $email,
    force  => undef,
  );

sub generated_files {
  my $opts = shift;
  my @modules =
    (ref $opts->{module} eq 'ARRAY' ? @{ $opts->{module} } : $opts->{module});

  my $starter_dir = $modules[0];

  $starter_dir =~ s/::/-/g;

  my %generated_files =
    (
     $starter_dir                                 => 'd',
     catfile($starter_dir, 'lib')                 => 'd',
     catfile($starter_dir, 'MANIFEST')            => 'f',
     catfile($starter_dir, 't')                   => 'd',
     catfile($starter_dir, 't', 'pod-coverage.t') => 'f',
     catfile($starter_dir, 't', '00-load.t')      => 'f',
     catfile($starter_dir, 't', 'boilerplate.t')  => 'f',
     catfile($starter_dir, 't', 'pod.t')          => 'f',
     catfile($starter_dir, 'README')              => 'f',
     catfile($starter_dir, 'Changes')             => 'f',
     catfile($starter_dir, '.cvsignore')          => 'f',
    );

  foreach my $module (@modules){
    my @parts = split(/::/, $module);

    my $pm = pop @parts;

    my $filename = catfile(@parts, "${pm}.pm");
    $generated_files{catfile($starter_dir, 'lib', $filename)} = 'f';

    while(@parts){
      my $dirname = catfile(@parts);
      $generated_files{catfile($starter_dir, 'lib', $dirname)} = 'd';
      pop @parts;
    }
  }

  my $builder_set = new Module::Starter::BuilderSet;
  my @builders = $builder_set->check_compatibility($opts->{builder});
  foreach my $builder (@builders){
    my $build_file = $builder_set->file_for_builder($builder);
    $generated_files{catfile($starter_dir, $build_file)} = 'f';
  }

  return %generated_files;
}

sub check_generated_files {
  my $opts = shift;

  my %generated_files = generated_files($opts);

  my $all_files_correct = 1;
  while (my($k,$v) = each %generated_files) {
    if ($v eq 'f') {
      $all_files_correct = 0 unless -f $k;
    } elsif ($v eq 'd') {
      $all_files_correct = 0 unless -d $k;
    } else {
      # Not a directory or file?  Weird.
      $all_files_correct = 0;
    }
  }

  my @modules =
    (ref $opts->{module} eq 'ARRAY' ? @{ $opts->{module} } : $opts->{module});

  my $starter_dir = $modules[0];

  $starter_dir =~ s/::/-/g;

 TODO: {
    local $TODO = "need to generate META.yml";
    ok(-f catfile($starter_dir, 'META.yml'), "META.yml exists");
  };

  ok($all_files_correct, "All files present and accounted for");

  my $num_extra_files = 0;

  find({ wanted   => sub {
             unless( exists $generated_files{$File::Find::name} ){
                 $num_extra_files++;
                 carp("found extra file: $File::Find::name");
             }
         },
         no_chdir => 1
       },
       $starter_dir
      );

  is($num_extra_files, 0, "No extra files");

}

sub catfile {
  File::Spec->catfile('a','b') =~ /^a(.+)b$/;
  my $separator = $1;

  my @parts = @_;

  return join($separator,
              # strip trailing directory separators
              map { my $part = $_; $part =~ s/$separator$//; $part } @parts
              );
}

sub build_module_starter {
  my $opts = shift;

  $opts->{module} = "" unless exists $opts->{module};
  $opts->{builder} = "" unless exists $opts->{builder};

  my $starter_dir =
    (ref $opts->{module} eq 'ARRAY' ? $opts->{module}->[0] : $opts->{module} );

  $starter_dir =~ s/::/-/g;

  # Now to try to build the Starter module...
  chdir( catfile($temp_dir,$starter_dir) );

  (my($path, $perl)) = $EXECUTABLE_NAME =~ /^(.+)(perl.*)$/i;

  $perl = catfile($path,$perl);

  (my @dirs) = ( $old_path =~ /([^;:]+)(?:;|:|$)/g );

  my $path_sep;

  if ($old_path eq join(":", @dirs)) {
    $path_sep = ":";
  } elsif ($old_path eq join(";", @dirs)) {
    $path_sep = ";";
  }

  my $builder_set = new Module::Starter::BuilderSet;

  # Use only the supported builders which are not mutually exclusive
  my @builders;
  # Capture warnings printed to STDERR
  {
      local *STDERR;
      open STDERR, q{>}, File::Spec->devnull();

      @builders = $builder_set->check_compatibility($opts->{builder});
  }

  foreach my $builder ( @builders ){
    my @commands = $builder_set->instructions_for_builder($builder);

    # ensure that we use the correct perl
    @commands =
      map { my $cmd = $_; $cmd =~ s/\bperl\b/$perl/; $cmd } @commands;

    my %commands;
    my %build_path;

    # Find tools needed by the builder
    my @deps = $builder_set->deps_for_builder($builder);
    foreach my $dir ( @dirs ) {
      foreach my $dependency ( @deps ){
        if( grep { -x catfile($dir, $_) } @{ $dependency->{aliases} } ){
          $build_path{$dir} = 1;
          $commands{$dependency->{command}} = 1;
        }
      }
    }

    my $build_path = join($path_sep, keys %build_path);
    my $env = "PERL5LIB=\$PERL5LIB:$test_libpath PATH=$build_path";

  SKIP: {
      skip( "Can't find dependencies for $builder", int(@commands) )
        if grep { !exists( $commands{ $_->{command} } ) } @deps;

      foreach my $command (@commands){
        my $cmd = "$env $command > /dev/null 2>&1";
        diag "RUNNING: $cmd";
        if( $command !~ /install/ ){
            system( $cmd );

            is($?, 0, "$builder: $cmd");

        }else{
        TODO: {
            local $TODO = "install tests not yet designed";

            is(1, 0, "$builder: $cmd");
          };
        }
      }
    }
  }

  chdir( $temp_dir );
}

sub run_module_starter {
  my %opts = @_;

  my $command = $module_starter;
  my @option_string = ("");

  while(my($k,$v) = each(%opts)){
    if( ref $v eq 'ARRAY' &&
        int( @$v ) > 1
      ){

      # If the option is multi-valued, we will test both formats:
      #
      # --option=value0 --option=value1
      # and
      # --option=value0,value1

      $option_string[1] = $option_string[0] unless($option_string[1]);

      $option_string[0] .= join( " ", map { " --$k='$_'" } @$v );

      my $COMMA= q{,};
      $option_string[1] .= " --$k=" . join( $COMMA, @$v );

    }else{
      # in case anyone ever decides to pass a single-valued arrayref
      $v = $v->[0] if ref $v eq 'ARRAY';

      # Make sure we append to the multi-value option string if it
      # exists
      for(my $i = 0; $i < int(@option_string) ; $i++ ){
        # Flags have no value
        $option_string[$i] .= " --$k" . ($v ? "='$v'" : '');
      }
    }
  }

  my $starter_dir = 
    (ref $opts{module} eq 'ARRAY' ? $opts{module}->[0] : $opts{module} );

  $starter_dir =~ s/::/-/g;

  foreach my $options ( @option_string ){

    my $env = "PERL5LIB=\$PERL5LIB:$test_libpath";
    $env .= " MODULE_STARTER_DIR=$config_dir" if -f $config_file;

    system( "$env $command $options 2>&1 >/dev/null" );
    is($?, 0, "$env $command $options" );

    check_generated_files(\%opts);

    build_module_starter(\%opts);
  }
}

ok( -f $changes_filename, '[paranoia] Dist dir contains Changes file' );
ok( -d $test_dir,         '[paranoia] Dist dir contains t/' );
ok( -f $module_starter,   '[paranoia] module_starter file exists' );
ok( -x $module_starter,   '[paranoia] module_starter is executable' );

chdir( $temp_dir );

# Compute the number of tests for the plan with these variables:
#
# $x:    no. of command line argument formats (1 for single args, 2 for multi)
# $y:    no. of builders.  if none passed, uses default builder
# z($y): no. of commands in builder $y's @instructions list
# tests += $x *      # $x command line argument formats
#          ( 1 +     # module-starter ran correctly
#            3 +     # files generated correctly
#            ( $y *  # $y builders
#              z($y) # number of commands in this builder $y's @instructions
#             )
#           )

# run with one module.
# default builder has 4 commands.
# tests += 1 * ( 1 + 3 + ( 1 * 4 ) ) = 8
run_module_starter( %options, module => 'Foo::Bar' );

# run with two modules.
# default builder has 4 commands.
# tests += 2 * ( 1 + 3 + ( 1 * 4 ) ) = 16
run_module_starter( %options, module => [ 'Foo::Bar', 'Foo::Baz' ] );

# run with two modules and a couple of builders.
# both builders have 4 commands.
# tests += 2 * ( 1 + 3 + ( 2 * 4 ) ) = 24
run_module_starter( %options,
                    module  => [ 'Foo::Bar', 'Foo::Baz' ],
                    builder => [ 'Module::Build', 'ExtUtils::MakeMaker' ],
                  );

# run with one module, default builder, and our example plug-in
# tests += 1 * ( 1 + 3 + ( 1 * 4 ) ) = 8
open my $fh, q{>}, $config_file or
  die "couldn't open config file '$config_file' for writing: $!";
print $fh "template_dir:  $template_dir\n";
close $fh;

run_module_starter ( %options,
                     module       => [ 'Foo::Bar' ],
                     plugin       => [ 'Module::Starter::TestPlugin' ],
                   );

unlink $config_file;

chdir( $dist_dir );
