#perl -T

# This test suite ensures that Module::Starter::BuilderSet behaves

use strict;
use warnings;

use Test::More tests => 17;

eval "require Module::Starter::BuilderSet";

ok(!$@, 'require Module::Starter::BuilderSet');

my $bset = new Module::Starter::BuilderSet;

isa_ok($bset, 'Module::Starter::BuilderSet');

can_ok($bset, qw( default_builder
                  supported_builders
                  file_for_builder
                  instructions_for_builder
                  deps_for_builder
                  method_for_builder
                  check_compatibility
                )
      );

ok( ( grep { $bset->default_builder() eq $_ } $bset->supported_builders() ),
    'default builder is in the list of supported builders'
  );

ok( ( !grep { !$bset->file_for_builder($_) } $bset->supported_builders() ),
    'all supported builders claim to generate a file'
  );

ok( (!grep {!$bset->instructions_for_builder($_)} $bset->supported_builders()),
    'all supported builders provide build instructions'
  );

foreach my $builder ( $bset->supported_builders() ){
  foreach my $dep ($bset->deps_for_builder($builder)){

    ok( exists $dep->{command} && $dep->{command} ne '',
        "dependency command for '$builder' is set"
      );

    ok(exists $dep->{aliases} &&
       ref $dep->{aliases} eq 'ARRAY' &&
       int( @{ $dep->{aliases} } ) > 0,
       "aliases look correct for builder '$builder', dep '$dep->{command}'"
      );
  }
}

use Module::Starter::Simple;
my $simple = bless {}, 'Module::Starter::Simple';

can_ok( $simple,
        map { $bset->method_for_builder($_) } $bset->supported_builders()
      );

my @incompat =
  (
   'ExtUtils::MakeMaker',
   'Module::Install',
  );

my @compat =
  ( 'Module::Build',
    'Module::Install',
  );

my @nonexistent =
  ( 'CJAC::Boing',
    'CJAC::Flop',
  );

ok( int( $bset->check_compatibility() ) == 1 &&
    ( $bset->check_compatibility() )[0] eq $bset->default_builder(),
    'check_compatibility() with no args returns default builder'
  );

my @return;

# Capture warnings printed to STDERR
{
    local *STDERR;
    open STDERR, q{>}, File::Spec->devnull();

    @return = $bset->check_compatibility(@nonexistent);
}
ok( int( @return ) == 1 &&
    $return[0] eq $bset->default_builder(),
    'check_compatibility() with unsupported builder returns default builder'
  );

my @return2;
# Capture warnings printed to STDERR
{
    local *STDERR;
    open STDERR, q{>}, File::Spec->devnull();

    @return  = $bset->check_compatibility(@incompat);
    @return2 = $bset->check_compatibility(reverse @incompat);
}

ok( int( @return ) != int( @incompat ),
    'check_compatibility() strips incompatible builder'
  );

ok( $return[0] eq $incompat[0] && $return2[0] eq $incompat[-1],
    'check_compatibility() gives precidence to the first module passed'
  );

is_deeply( [($bset->check_compatibility(@compat))],
           [@compat],
           "check_compatibility() returns all compatible builders"
         );

# Capture warnings printed to STDERR
{
    local *STDERR;
    open STDERR, q{>}, File::Spec->devnull();

    @return = $bset->check_compatibility(@compat, @incompat, @nonexistent);
}

is_deeply( \@return, \@compat,
           "check_compatibility() returns only compatible builders ".
           "when given mixed set of compatible, incompatible and nonsense"
         );
