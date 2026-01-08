#!perl

use strict;
use warnings;

use Test::More;
use Module::Starter::App ();
use Module::Starter::Simple;
use File::Temp qw( tempdir );

# Test if author strings from configuration file get split correctly.
subtest 'Test author splits from config file' => sub {
    subtest 'Valid author strings' => sub {
        my %VALID = (
            'single author' => {
                author   => 'Andy Lester <andy@petdance.com>',
                expected => [
                    'Andy Lester <andy@petdance.com>',
                ],
            },
            'multiple authors; space separated' => {
                author   => 'Andy Lester <andy@petdance.com> Sawyer X <sawyerx@cpan.org>',
                expected => [
                    'Andy Lester <andy@petdance.com>',
                    'Sawyer X <sawyerx@cpan.org>',
                ],
            },
            'multiple authors; comma separated' => {
                author   => 'Andy Lester <andy@petdance.com>, Sawyer X <sawyerx@cpan.org>',
                expected => [
                    'Andy Lester <andy@petdance.com>',
                    'Sawyer X <sawyerx@cpan.org>',
                ],
            },
            'multiple authors; whitespace separated' => {
                author   => qq{Andy Lester\t<andy\@petdance.com>\t\tSawyer  X  <sawyerx\@cpan.org>\t},
                expected => [
                    qq{Andy Lester\t<andy\@petdance.com>},
                    'Sawyer  X  <sawyerx@cpan.org>',
                ],
            },
            'multiple authors; punctuation' => {
                author   => q{Andy L. <andy@petdance.com> 'Sawyer X' <sawyerx@cpan.org>},
                expected => [
                    'Andy L. <andy@petdance.com>',
                    q{'Sawyer X' <sawyerx@cpan.org>},
                ],
            },
            'multiple authors; punctuation + whitespace + comma' => {
                author   => qq{Andy-Lester'   <andy\@petdance.com>  ,\t" Sawyer X. " <sawyerx\@cpan.org>  },
                expected => [
                    q{Andy-Lester'   <andy@petdance.com>},
                    q{" Sawyer X. " <sawyerx@cpan.org>},
                ],
            },
        );

        foreach my $name ( sort keys %VALID ) {
            my %config = Module::Starter::App->_config_multi_process( author => $VALID{$name}->{author} );

            is_deeply( $config{author}, $VALID{$name}->{expected}, "Split match ($name)" );
        }
    };

    subtest 'Invalid author strings' => sub {
        subtest 'Do not split' => sub {
            my @INVALID = (
                'Andy Lester andy@petdance.com Sawyer X <sawyerx@cpan.org>',
                'Andy Lester<andy@petdance.com> Sawyer X <sawyerx@cpan.org>',
                'Andy Lester <<andy@petdance.com> Sawyer X <sawyerx@cpan.org>',
                'Andy Lester <andy@petdance.com>> Sawyer X <sawyerx@cpan.org>',
                'Andy Lester <andy@petdance.com>Sawyer X <sawyerx@cpan.org>',
                'Andy Lester <andy@petdance.com Sawyer X <sawyerx@cpan.org>',
                'Andy Lester andy@petdance.com> Sawyer X <sawyerx@cpan.org>',
                'Andy Lester <> Sawyer X <sawyerx@cpan.org>',
            );

            foreach my $author ( @INVALID ) {
                my %config = Module::Starter::App->_config_multi_process( author => $author );

                is_deeply( $config{author}, [ $author ], 'String match' );
            }
        };

        subtest 'Split incorrectly' => sub {
            my %INVALID = (
                'Andy Lester <andy@petdance.com> Sawyer X sawyerx@cpan.org Dan Book <dbook@cpan.org' =>
                    'Sawyer X sawyerx@cpan.org Dan Book <dbook@cpan.org',

                'Andy Lester <andy@petdance.com> Sawyer X<sawyerx@cpan.org> Dan Book <dbook@cpan.org' =>
                    'Sawyer X<sawyerx@cpan.org> Dan Book <dbook@cpan.org',

                'Andy Lester <andy@petdance.com> Sawyer X <<sawyerx@cpan.org> Dan Book <dbook@cpan.org>' =>
                    'Sawyer X <<sawyerx@cpan.org> Dan Book <dbook@cpan.org>',

                'Andy Lester <andy@petdance.com> Sawyer X <sawyerx@cpan.org>> Dan Book <dbook@cpan.org>' =>
                    'Sawyer X <sawyerx@cpan.org>> Dan Book <dbook@cpan.org>',

                'Andy Lester <andy@petdance.com> Sawyer X <sawyerx@cpan.org>Dan Book <dbook@cpan.org' =>
                    'Sawyer X <sawyerx@cpan.org>Dan Book <dbook@cpan.org',

                'Andy Lester <andy@petdance.com> Sawyer X <sawyerx@cpan.org Dan Book <dbook@cpan.org' =>
                    'Sawyer X <sawyerx@cpan.org Dan Book <dbook@cpan.org',

                'Andy Lester <andy@petdance.com> Sawyer X sawyerx@cpan.org> Dan Book <dbook@cpan.org' =>
                    'Sawyer X sawyerx@cpan.org> Dan Book <dbook@cpan.org',

                'Andy Lester <andy@petdance.com> Sawyer X <> Dan Book <dbook@cpan.org' =>
                    'Sawyer X <> Dan Book <dbook@cpan.org',
            );

            foreach my $author ( sort keys %INVALID ) {
                my %config = Module::Starter::App->_config_multi_process( author => $author );

                is_deeply( $config{author}, [ 'Andy Lester <andy@petdance.com>', $INVALID{$author} ], 'Split match' );
            }
        };
    };
};

# Test validation of author strings.
# Spec: 'Author Name <author-email@domain.tld>'
#
# NOTE:
#   Do not test valid strings since the distro would be created at every iteration,
#   which generates unnecessary IO/noise.
subtest 'Test author string validation' => sub {
    my @INVALID = (
        '<>',

        'Andy Lester',
        'Andy Lester<andy@petdance.com>',
        'Andy Lester <<andy@petdance.com>',
        'Andy Lester <andy@petdance.com>>',
        'Andy Lester <andy@petdance.com',
        'Andy Lester andy@petdance.com>',
        'Andy Lester <>',

        'Andy Lester <andy@petdance.com> Sawyer X <sawyerx@cpan.org>',
        'Andy Lester <andy@petdance.com Sawyer X <sawyerx@cpan.org>',
        'Andy Lester andy@petdance.com> Sawyer X sawyerx@cpan.org>',
        'Andy Lester <> Sawyer X <>',

        'Andy Lester <andy@petdance.com> Sawyer X <sawyerx@cpan.org> Dan Book <dbook@cpan.org',
    );

    my $CROAK_MSG = q{author strings must be in the format: 'Author Name <author-email@domain.tld>'};

    my $tempdir = tempdir( CLEANUP => 1 );

    foreach my $author ( @INVALID ) {
        my $ms = Module::Starter::Simple->new(
            dir     => $tempdir,
            modules => [ qw( Foo::Bar ) ],
            author  => [ $author ],
        );

        my $err = do {
            local $@;
            eval { $ms->create_distro };
            $@;
        };

        ok( $err, qq{Invalid author: '$author'} );
        like( $err, qr/\A$CROAK_MSG/, 'Croak msg match' );
    }
};

done_testing();
