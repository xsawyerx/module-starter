#!perl

use strict;
use warnings;

use Test::More 'tests' => 10;
use Module::Starter::Simple;
use File::Spec;

sub slurp_file {
    my $file = shift;
    open my $fh, '<', $file
        or die "Cannot create file $file: $!";
    my $content = do { undef $/; <$fh> };
    close $fh
        or die "Cannot close file: $file: $!";
    return $content;
}

sub write_file {
    my ( $file, $content ) = @_;
    open my $fh, '>', $file
        or die "Cannot create file $file: $!";
    print {$fh} $content;
    close $fh
        or die "Cannot close file: $file: $!";
}

my $rand = int rand 99999;
my $tmpdir = "/tmp/MyTestDir_$rand";
ok( !-d $tmpdir, "Test directory ($tmpdir) does not exist" );

my $simple_force = Module::Starter::Simple->new(
    'distro'  => 'Foo',
    'basedir' => $tmpdir,
    'force'   => 1,
);
isa_ok( $simple_force, 'Module::Starter::Simple' );
$simple_force->create_basedir();
ok( -d $tmpdir, "Test directory ($tmpdir) created" );

my $test_file = File::Spec->catfile($tmpdir, "foo");
write_file( $test_file, 'ok' );
ok( -f $test_file, "Created test file ($test_file) successfully" );
$simple_force->create_basedir();
ok( -f $test_file, "Test file ($test_file) still exists after trying to recreate basedir" );
is( slurp_file($test_file), 'ok', 'Force did not delete unrelated files' );

$simple_force->create_Changes();
my $changes_file = File::Spec->catfile($tmpdir, 'Changes');
ok( -f $changes_file, 'Changes file created' );
my $changes = slurp_file($changes_file);
ok( length $changes, 'Got Changes file content' );

my $bowie_chant = 'Ch-ch-ch-ch-changes';
write_file( $changes_file, $bowie_chant );
my $simple_nonforce = Module::Starter::Simple->new(
    'distro'  => 'Foo',
    'basedir' => $tmpdir,
);
$simple_nonforce->create_Changes();
is( slurp_file($changes_file), $bowie_chant, 'Changes file was not rewritten without force' );

$simple_force->create_Changes();
my $recreated_changes = slurp_file($changes_file);
is( $recreated_changes, $changes, 'Changes file rewritten correctly' );
