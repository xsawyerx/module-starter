#!perl -T

use strict;
use warnings;
use Test::More;

# End-users shouldn't need to run these tests
plan skip_all => "Skipping author tests" if not $ENV{AUTHOR_TESTING};

# Ensure a recent version of Test::Pod
my $min_tp = 1.22;
eval "use Test::Pod $min_tp";
plan skip_all => "Test::Pod $min_tp required for testing POD" if $@;

all_pod_files_ok();
