#!perl -T

use strict;
use warnings;

use Test::More tests => 4;

use_ok( 'Module::Starter' );
use_ok( 'Module::Starter::Simple' );
use_ok( 'Module::Starter::BuilderSet' );
use_ok( 'Module::Starter::Plugin::Template' );

diag( "Testing Module::Starter $Module::Starter::VERSION, Perl $], $^X" );
