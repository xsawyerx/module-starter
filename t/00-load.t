#!perl -T

use strict;
use warnings;

use Test::More tests => 3;

use_ok( 'Module::Starter' );
use_ok( 'Module::Starter::Simple' );
use_ok( 'Module::Starter::Plugin::Template' );

diag( "Testing Module::Starter $Module::Starter::VERSION, Perl $], $^X" );
