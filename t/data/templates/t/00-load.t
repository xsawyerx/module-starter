#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Foo::Bar' );
}

diag( "Testing Foo::Bar $Foo::Bar::VERSION, Perl $], $^X" );
