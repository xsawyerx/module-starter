#perl -T

# This test suite ensures that Module::Starter::BuilderSet behaves

use strict;
use warnings;

use Test::More;

require_ok 'Module::Starter::BuilderSet';
my $bset = new_ok 'Module::Starter::BuilderSet';

can_ok($bset, qw( default_builder
                  supported_builders
                  file_for_builder
                  instructions_for_builder
                  deps_for_builder
                  method_for_builder
                  check_compatibility
                )
      );

my @supported = $bset->supported_builders();
#plan tests => (15 + @supported*2);
# "Plan (1..XX) must be at the beginning or end of the TAP output"
# Fine, we'll stuff it on the end...
      
ok( scalar grep { $bset->default_builder() eq $_ } @supported,
    'default builder is in the list of supported builders'
  );

is_deeply( [ grep { $bset->file_for_builder($_) } @supported ],
    \@supported,
    'all supported builders claim to generate a file'
  );

is_deeply( [ grep { $bset->instructions_for_builder($_) } @supported ],
    \@supported,
    'all supported builders provide build instructions'
  );

foreach my $builder (@supported) {
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

use_ok 'Module::Starter::Simple';
my $simple = new_ok 'Module::Starter::Simple';

can_ok( $simple,
        map { $bset->method_for_builder($_) } $bset->supported_builders()
      );

### check_compatibility tests ###
      
my @incompat =
  (
   'ExtUtils::MakeMaker',
   'Module::Install',
  );

my @compat =
  ( 'Module::Build',
    'Module::Install',
    'Dist::Zilla',
  );

my @nonexistent =
  ( 'CJAC::Boing',
    'CJAC::Flop',
  );

sub cc_quiet {
   local $SIG{__WARN__} = sub {};  # As the 'IGNORE' hook is not supported by __WARN__ , you can disable warnings using the empty subroutine
   return $bset->check_compatibility(@_);
}  
  
my @return = cc_quiet();
is( int( @return ), 1,                    'check_compatibility() with no args returns 1 builder');
is( $return[0], $bset->default_builder(), 'check_compatibility() with no args returns default builder');

@return = cc_quiet(@nonexistent);
is( int( @return ), 1,                    'check_compatibility() with unsupported builder returns 1 builder');
is( $return[0], $bset->default_builder(), 'check_compatibility() with unsupported builder returns default builder');

   @return  = cc_quiet(@incompat);
my @return2 = cc_quiet(reverse @incompat);
isnt( int(@return), int(@incompat), 'check_compatibility() strips incompatible builder');

is_deeply( [ $return[0], $return2[0] ], [ $incompat[0], $incompat[-1] ],
    'check_compatibility() gives precidence to the first module passed'
);

is_deeply( [(cc_quiet(@compat))],
           [@compat],
           "check_compatibility() returns all compatible builders"
         );

@return = cc_quiet(@compat, @incompat, @nonexistent);
is_deeply( \@return, \@compat,
           "check_compatibility() returns only compatible builders ".
           "when given mixed set of compatible, incompatible and nonsense"
         );

plan tests => (15 + @supported*2);
done_testing;
