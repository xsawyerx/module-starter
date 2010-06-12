package Module::Starter::App;

=head1 NAME

Module::Starter::App - the code behind the command line program

=cut

use warnings;
use strict;

our $VERSION = '1.55_01';

use Path::Class;
use Getopt::Long;
use Pod::Usage;
use Carp qw( croak );

sub _config_file {
    my $class     = shift;
    my $configdir = $ENV{'MODULE_STARTER_DIR'} || '';

    if ( !$configdir && $ENV{'HOME'} ) {
        $configdir = dir( $ENV{'HOME'}, '.module-starter' );
    }

    return file( $configdir, 'config' );
}


sub _config_read {
    my $class = shift;

    my $filename = $class->_config_file;

    return unless -e $filename;

    open( my $config_file, '<', $filename )
        or die "couldn't open config file $filename: $!\n";

    my %config;
    while (<$config_file>) {
        chomp;
        next if /\A\s*\Z/sm;
        if (/\A(\w+):\s*(.+)\Z/sm) { $config{$1} = $2; }
    }

    # The options that accept multiple arguments must be set to an
    # arrayref
    $config{plugins} = [ split /(?:\s*,\s*|\s+)/, $config{plugins} ] if $config{plugins};
    $config{builder} = [ split /(?:\s*,\s*|\s+)/, $config{builder} ] if $config{builder};

    foreach my $key ( qw( plugins modules builder ) ){
        $config{$key} = [] unless exists $config{$key};
    }

    return %config;
}

sub _process_command_line {
    my ( $self, %config ) = @_;

    $config{'argv'} = [ @ARGV ];

    pod2usage(2) unless @ARGV;

    GetOptions(
        'class=s'    => \$config{class},
        'plugin=s@'  => \$config{plugins},
        'dir=s'      => \$config{dir},
        'distro=s'   => \$config{distro},
        'module=s@'  => \$config{modules},
        'builder=s@' => \$config{builder},
        eumm         => sub { push @{$config{builder}}, 'ExtUtils::MakeMaker' },
        mb           => sub { push @{$config{builder}}, 'Module::Build' },
        mi           => sub { push @{$config{builder}}, 'Module::Install' },

        'author=s'   => \$config{author},
        'email=s'    => \$config{email},
        'license=s'  => \$config{license},
        force        => \$config{force},
        verbose      => \$config{verbose},
        version      => sub {
            require Module::Starter;
            print "module-starter v$Module::Starter::VERSION\n";
            exit 1;
        },
        help         => sub { pod2usage(1); },
    ) or pod2usage(2);

    if (@ARGV) {
        pod2usage(
            -msg =>  "Unparseable arguments received: " . join(',', @ARGV),
            -exitval => 2,
        );
    }

    $config{class} ||= 'Module::Starter';

    $config{builder} = ['ExtUtils::MakeMaker'] unless $config{builder};

    return %config;
}

=head2 run

  Module::Starter::App->run;

This is equivalent to running F<module-starter>. Its behavior is still subject
to change.

=cut

sub run {
    my $class  = shift;
    my %config = $class->_config_read;

    %config = $class->_process_command_line(%config);

    eval "require $config{class};";
    croak "Could not load starter class $config{class}: $@" if $@;
    $config{class}->import( @{ $config{'plugins'} } );

    my $starter = $config{class}->new( %config );
    $starter->postprocess_config;
    $starter->pre_create_distro;
    $starter->create_distro;
    $starter->post_create_distro;
    $starter->pre_exit;

    return 1;
}

1;
