package Module::Starter::Plugin::Template;
# vi:et:sw=4 ts=4

use warnings;
use strict;
use Carp qw( confess );

=head1 NAME

Module::Starter::Plugin::Template - module starter with templates

=head1 VERSION

Version 1.470

    $Id: Template.pm 54 2007-02-06 22:04:46Z andy $

=cut

our $VERSION = '1.470';

=head1 SYNOPSIS

 use Module::Starter qw(
   Module::Starter::Simple
   Module::Starter::Plugin::Template
 );

 Module::Starter->create_distro(%args);

=head1 DESCRIPTION

This plugin is designed to be added to a Module::Starter::Simple-compatible
Module::Starter class.  It adds stub methods for template retrieval and
rendering, and it replaces all of Simple's _guts methods with methods that will
retrieve and render the apropriate templates.

=head1 CLASS METHODS

=head2 C<< new(%args) >>

This plugin calls the C<new> supermethod and then initializes the template
store and renderer.  (See C<templates> and C<renderer> below.)

=cut

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    $self->{templates} = { $self->templates };
    $self->{renderer} = $self->renderer;
    return bless $self => $class;
}

=head1 OBJECT METHODS

=head2 C<< templates() >>

This method is used to initialize the template store on the Module::Starter
object.  It returns a hash of templates; each key is a filename and each value
is the body of the template.  The filename F<Module.pm> is used for the module
template.

=cut

sub templates {
    confess 'attempted to use abstract base templates method';
}

=head2 C<< renderer() >>

This method is used to initialize the template renderer.  Its result is stored
in the object's C<renderer> entry.  The implementation will determine its use.

=cut

sub renderer {
    confess 'attempted to use abstract base renderer method';
}

=head2 C<< render($template, \%options) >>

The C<render> method will render the template passed to it, using the
data in the Module::Starter object and in the hash of passed parameters.

=cut

sub render {
    my $self = shift;
    my $template = shift;
    my $options = shift;

    confess 'attempted to use abstract base render method';
}

=head2 _guts methods

All of the C<FILE_guts> methods from Module::Starter::Simple are subclassed to
look something like this:

    sub file_guts {
        my $self = shift;
        my %options;
        @options{qw(first second third)} = @_;

        my $template = $self->{templates}{filename};
        $self->render($template, \%options);
    }

These methods will need to be rewritten when (as is likely)
Module::Starter::Simple's _guts methods are refactored into a registry.

=over 4

=item module_guts

=cut

sub module_guts {
    my $self = shift;
    my %options;
    @options{qw(module rtname)} = @_;

    my $template = $self->{templates}{'Module.pm'};
    $self->render($template, \%options);
}

=item Makefile_PL_guts

=cut

sub Makefile_PL_guts {
    my $self = shift;
    my %options;
    @options{qw(main_module main_pm_file)} = @_;

    my $template = $self->{templates}{'Makefile.PL'};
    $self->render($template, \%options);
}

=item MI_Makefile_PL_guts

=cut

sub MI_Makefile_PL_guts {
    my $self = shift;
    my %options;
    @options{qw(main_module main_pm_file)} = @_;

    my $template = $self->{templates}{'MI_Makefile.PL'};
    $self->render($template, \%options);
}

=item Build_PL_guts

=cut

sub Build_PL_guts {
    my $self = shift;
    my %options;
    @options{qw(main_module main_pm_file)} = @_;

    my $template = $self->{templates}{'Build.PL'};
    $self->render($template, \%options);
}

=item Changes_guts

=cut

sub Changes_guts {
    my $self = shift;

    my $template = $self->{templates}{'Changes'};
    $self->render($template);
}

=item README_guts

=cut

sub README_guts {
    my $self = shift;
    my %options;
    @options{qw(build_instructions)} = @_;

    my $template = $self->{templates}{'README'};
    $self->render($template, \%options);
}

=item t_guts

=cut

sub t_guts {
    my $self = shift;
    my %options;
    $options{modules} = [ @_ ];

    my %t_files;

    foreach (grep { /\.t$/ } keys %{$self->{templates}}) {
        my $template = $self->{templates}{$_};
        $t_files{$_} = $self->render($template, \%options);
    }

    return %t_files;
}

=item MANIFEST_guts

=cut

sub MANIFEST_guts {
    my $self = shift;
    my %options;
    $options{files} = [ sort @_ ];

    my $template = $self->{templates}{MANIFEST};
    $self->render($template, \%options);
}

=item item cvsignore_guts

=cut

sub cvsignore_guts {
    my $self = shift;

    my $template = $self->{templates}{cvsignore};
    $self->render($template);
}

=back

=head1 AUTHOR

Ricardo SIGNES, C<< <rjbs at cpan.org> >>

=head1 Bugs

Please report any bugs or feature requests to
C<bug-module-starter at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll automatically be
notified of progress on your bug as I make changes.

=head1 COPYRIGHT

Copyright 2005-2007 Ricardo SIGNES, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
