package Module::Starter;

use warnings;
use strict;
use Carp qw( croak );
use Module::Runtime qw( require_module );

=head1 NAME

Module::Starter - a simple starter kit for any module

=cut

our $VERSION = '1.77';

=head1 SYNOPSIS

Nothing in here is meant for public consumption.  Use L<module-starter>
from the command line.

    module-starter --module=Foo::Bar,Foo::Bat \
        --author="Andy Lester" --email=andy@petdance.com

=head1 DESCRIPTION

This is the core module for Module::Starter.  If you're not looking to extend
or alter the behavior of this module, you probably want to look at
L<module-starter> instead.

Module::Starter is used to create a skeletal CPAN distribution, including basic
builder scripts, tests, documentation, and module code.  This is done through
just one method, C<create_distro>.

=head1 METHODS

=head2 Module::Starter->create_distro(%args)

C<create_distro> is the only method you should need to use from outside this
module; all the other methods are called internally by this one.

This method creates orchestrates all the work; it creates distribution and
populates it with the all the requires files.

It takes a hash of params, as follows:

    distro       => $distroname,      # distribution name (defaults to first module)
    modules      => [ module names ], # modules to create in distro
    dir          => $dirname,         # directory in which to build distro
    builder      => 'Module::Build',  # defaults to ExtUtils::MakeMaker
                                      # or specify more than one builder in an
                                      # arrayref

    license      => $license,  # type of license; defaults to 'artistic2'
    author       => $author,   # author's full name (taken from C<getpwuid> if not provided)
    email        => $email,    # author's email address (taken from C<EMAIL> if not provided)
    ignores_type => $type,     # ignores file type ('generic', 'cvs', 'git', 'hg', 'manifest' )
    fatalize     => $fatalize, # generate code that makes warnings fatal

    verbose      => $verbose,  # bool: print progress messages; defaults to 0
    force        => $force     # bool: overwrite existing files; defaults to 0

The ignores_type is a new feature that allows one to create SCM-specific ignore files.
These are the mappings:

    ignores_type => 'generic'  # default, creates 'ignore.txt'
    ignores_type => 'cvs'      # creates .cvsignore
    ignores_type => 'git'      # creates .gitignore
    ignores_type => 'hg'       # creates .hgignore
    ignores_type => 'manifest' # creates MANIFEST.SKIP

It is also possible to provide an array ref with multiple types wanted:

    ignores_type => [ 'git', 'manifest' ]

=head1 PLUGINS

Module::Starter itself doesn't actually do anything.  It must load plugins that
implement C<create_distro> and other methods.  This is done by the class's C<import>
routine, which accepts a list of plugins to be loaded, in order.

For more information, refer to L<Module::Starter::Plugin>.

=cut

sub import {
    my $class = shift;
    my @plugins = ((@_ ? @_ : 'Module::Starter::Simple'), $class);
    my $parent;

    while (my $child = shift @plugins) {
        require_module $child;

        ## no critic
        no strict 'refs'; #Violates ProhibitNoStrict
        push @{"${child}::ISA"}, $parent if $parent;
        use strict 'refs';
        ## use critic

        if ( @plugins && $child->can('load_plugins') ) {
            $parent->load_plugins(@plugins);
            last;
        }
        $parent = $child;
    }

    return;
}

=head1 AUTHORS

Dan Book, C<< <dbook at cpan.org> >>

Sawyer X, C<< <xsawyerx at cpan.org> >>

Andy Lester, C<< <petdance at cpan.org> >>

Ricardo Signes, C<< <rjbs at cpan.org> >>

C.J. Adams-Collier, C<< <cjac at colliertech.org> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Module::Starter

You can also look for information at:

=over 4

=item * Source code at GitHub

L<https://github.com/xsawyerx/module-starter>

=item * CPAN Ratings

L<http://cpanratings.perl.org/dist/Module-Starter>

=item * GitHub issue tracker

L<https://github.com/xsawyerx/module-starter/issues>

=item * Search CPAN

L<https://metacpan.org/release/Module-Starter>

=back

=head1 BUGS

Please report any bugs or feature requests to the bugtracker for this project
on GitHub at: L<https://github.com/xsawyerx/module-starter/issues>. I will be
notified, and then you'll automatically be notified of progress on your bug
as I make changes.

=head1 COPYRIGHT

Copyright 2005-2009 Andy Lester, Ricardo Signes and C.J. Adams-Collier,
All Rights Reserved.

Copyright 2010 Sawyer X, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

=over 4

=item L<mbtiny>

Minimal authoring tool to create and manage distributions using
L<Module::Build::Tiny> as an installer.

=item L<Dist::Milla>

Easy to use and powerful authoring tool using L<Dist::Zilla> to create and
manage distributions.

=item L<Minilla>

Authoring tool similar to L<Dist::Milla> but without using L<Dist::Zilla>.

=item L<Dist::Zilla>

Very complex, fully pluggable and customizable distribution builder.

=back

=cut

1;

# vi:et:sw=4 ts=4
