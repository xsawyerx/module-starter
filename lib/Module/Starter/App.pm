package Module::Starter::App;

=head1 NAME

Module::Starter::App - the code behind the command line program

=cut

use warnings;
use strict;

our $VERSION = '1.60';

use Config::INI::Reader;
use Path::Class;
use Getopt::Long;
use Pod::Usage;
use Carp qw( croak );

sub _config_file {
    my $self      = shift;
    my $configdir = $ENV{'MODULE_STARTER_DIR'} || '';

    if ( !$configdir && $ENV{'HOME'} ) {
        $configdir = dir( $ENV{'HOME'}, '.module-starter' );
    }

    my $r = file($configdir, 'config.ini');
    return -f $r ? $r : file( $configdir, 'config' );
}


sub _config_read {
    my $self = shift;

    my $filename = $self->_config_file;
    return unless -e $filename;

    if(substr($filename, -4) eq '.ini') {
      my $config = Config::INI::Reader->read_file($filename);
      $config->{__profilesupport} = 1;
      return $self->_config_multi_process(%$config);
    }

    open( my $config_file, '<', $filename )
        or die "couldn't open config file $filename: $!\n";

    my %config;
    while (<$config_file>) {
        chomp;
        next if /\A\s*\Z/sm;
        if (/\A(\w+):\s*(.+)\Z/sm) { $config{$1} = $2; }
    }

    return $self->_config_multi_process(%config);
}

sub _config_multi_process {
    my ( $self, %config ) = @_;

    # The options that accept multiple arguments must be set to an arrayref
    foreach my $key (qw( builder ignores_type modules plugins )) {
        $config{$key} = [ split /(?:\s*,\s*|\s+)/, (ref $config{$key} ? join(',', @{$config{$key}}) : $config{$key}) ] if $config{$key};
        $config{$key} = [] unless exists $config{$key};
    }

    return %config;
}

sub _process_command_line {
    my ( $self, %loadedConfig ) = @_;
    my %config;

    $config{'argv'} = [ @ARGV ];

    pod2usage(2) unless @ARGV;

    Getopt::Long::Configure('no_ignorecase_always');
    GetOptions(
        'P|profile=s'=> \$config{profile},
        'class=s'    => \$config{class},
        'plugin=s@'  => \$config{plugins},
        'dir=s'      => \$config{dir},
        'distro=s'   => \$config{distro},
        'module=s@'  => \$config{modules},
        'builder=s@' => \$config{builder},
        'ignores=s@' => \$config{ignores_type},
        eumm         => sub { push @{$config{builder}}, 'ExtUtils::MakeMaker' },
        mb           => sub { push @{$config{builder}}, 'Module::Build' },
        mi           => sub { push @{$config{builder}}, 'Module::Install' },

        'author=s'   => \$config{author},
        'email=s'    => \$config{email},
        'license=s'  => \$config{license},
        'minperl=s'  => \$config{minperl},
        force        => \$config{force},
        verbose      => \$config{verbose},
        version      => sub {
            require Module::Starter;
            print "module-starter v$Module::Starter::VERSION\n";
            exit 1;
        },
        help         => sub { pod2usage(1); },
    ) or pod2usage(2);

    my %c;
    if ( $loadedConfig{__profilesupport} ) {
        delete $loadedConfig{__profilesupport};
        my $profile = $config{profile};

        if ( $profile && !exists( $loadedConfig{$profile} ) ) {
            die pod2usage(
                {
                    -message =>
                      "\n\nERROR: Profile $profile does not exist\n\n",
                    -exitval => 2
                }
            );
        }

        %c = %{ $loadedConfig{_} };

        if ($profile) {
            for my $k ( keys( %{ $loadedConfig{$profile} } ) ) {
                $c{$k} = $loadedConfig{$profile}->{$k};
            }
        }

        for my $k ( keys(%config) ) {
            if ( $config{$k} || !exists($c{$k})) {
                $c{$k} = $config{$k};
            }
        }

    } else {
        %c = %loadedConfig;
        for my $k (keys(%config)) {
            if ( $config{$k} || !exists($c{$k})) {
                $c{$k} = $config{$k};
            }
        }
    }
    %config = %c;

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
    my $self   = shift;
    my %config = $self->_config_read;

    %config = $self->_process_command_line(%config);
    %config = $self->_config_multi_process(%config);

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
