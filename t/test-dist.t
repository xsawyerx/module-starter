#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Module::Starter;
use File::Spec;
use File::Path;
use Carp;

package TestParseFile;

use Test::More;
use File::Basename;

sub new {
    my $class = shift;
    my $self  = shift;
    $self //= {};
    $self->{_orig_vars} = { %$self };

    bless $self, $class;
    $self->_slurp_to_ref();
    
    return $self;
}

sub _text {
    my ($self, $text) = @_;
    
    if ($text) {
        unless (ref $text)             { $self->{_text} = \$text; }
        elsif  (ref $text eq 'SCALAR') { $self->{_text} = $text; }
        else                           { Carp::confess( 'Text must be a scalar type' ); }
    }

    return ${$self->{_text}};
}

sub _slurp_to_ref {
    my ($self) = @_;

    local $/;
    open my $in, '<', $self->{fn}
        or Carp::confess( "Cannot open ".$self->{fn} );
    $self->_text(<$in>);
    close($in);

    return $self->{_text};
}

sub _diag {
    my ($self) = @_;
    return diag explain $self->{_orig_vars};
}

sub parse {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ($self, $re, $msg) = @_;
    $msg ||= "Parsing $re";

    my $verdict = like($self->_text, $re, $self->format_msg($msg))
        or $self->_diag;

    ${$self->{_text}} =~ s{$re}{}ms if ($verdict);
        
    return $verdict;
}

sub consume {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ($self, $prefix, $msg) = @_;
    $msg ||= 'Contents';

    my $verdict =
        is( substr($self->_text, 0, length($prefix)),
            $prefix,
            $self->format_msg($msg))
        or $self->_diag;

    ${$self->{_text}} = substr($self->_text, length($prefix)) if ($verdict);

    return $verdict;
}

sub is_end {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ($self, $msg) = @_;
    $msg ||= "That's all folks!";

    my $verdict = is ($self->_text, "", $self->format_msg($msg))
        or $self->_diag;

    return $verdict;
}

# This is merely a copy of the license code from Module::Starter::Simple.
# We could just use $Module::Starter::Simple::LICENSES, but really
# it's bad form to use variables from the actual modules for the
# purposes of testing.

our $LICENSES = {
    Perl_5       => qr/^perl[v_]?5?$/,
    Artistic_1_0 => qr/^artistic[v_]?1\D?0?$/,
    Artistic_2_0 => qr/^artistic[v_]?2?\D?0?$/,
    MIT          => qr/^mit$/,
    Mozilla_1_1  => qr/^mozillav?1\D?1?$/,
    Mozilla_2_0  => qr/^mozillav?2?\D?0?$/,
    BSD          => qr/^bsd.*3(?:.*clause)/,
    FreeBSD      => qr/^(?:free)?bsd.*2?(?:.*clause)?/,
    CC0          => qr/^cc0$/,
    GPL_1        => qr/^gplv?1\D?0?$/,
    GPL_2        => qr/^gplv?2\D?0?$/,
    GPL_3        => qr/^gplv?3?\D?0?$/,
    LGPL_2       => qr/^lgplv?2\D?1?$/,
    LGPL_3       => qr/^lgplv?3?\D?0?$/,
    AGPL_3       => qr/^agplv?3?\D?0?$/,
    Apache_1_1   => qr/^apache[v_]?1\D?1?$/,
    Apache_2_0   => qr/^apache[v_]?2?\D?0?$/,
    QPL_1_0      => qr/^qplv?1?\D?0?$/,
    DWTFYWWI     => qr/^(?:dwtfywwi|wtfpl)v?1\D?0?$/,
    WTFPL_2      => qr/^(?:dwtfywwi|wtfpl)v?2\D?0?$/,
    PD           => qr/^(?:pd|public|public.*domain|unrestricted)$/,
    Beerware     => qr/^beer(?:ware)?[vr]?(?:42)?$/,
    PostgreSQL   => qr/^(?:pq|postgresql)$/,
    None         => qr/^(?:none$|restrict)/,
};

sub _license_record {
    my $self = shift;
    my $license = $self->{license};
    my $slname;
    
    # All of these monikers are lowercase, and since any S::L name is
    # going to have uppercase, it will win out.  This extra code will even
    # detect this and not bother with the translation.
    if (lc $license eq $license) {
        foreach my $sl (sort keys %$LICENSES) {
            if ($license =~ $LICENSES->{$sl}) { $slname = $sl; last; }
        }
        die "No such license moniker translation for '$license'" unless ($slname);
    }
    else { $slname = $license; }
    
    # Perl will die of natural causes in case of missing modules
    eval "require Software::License::$slname;";  # require hates string class names; must use eval string instead of block
    return "Software::License::$slname"->new({
        holder => $self->{author}
    });
}

=head2 $file_parser->parse_paras(\@paras, $message)

Parse the paragraphs paras. Paras can either be strings, in which case
they'll be considered plain texts. Or they can be hash refs with the key
're' pointing to a regex string.

Here's an example:

    my @synopsis_paras = (
        '=head1 SYNOPSIS',
        'Quick summary of what the module does.',
        'Perhaps a little code snippet.',
        { re => q{\s*} . quotemeta(q{use MyModule::Test;}), },
        { re => q{\s*} .
            quotemeta(q{my $foo = MyModule::Test->new();})
            . q{\n\s*} . quotemeta("..."), },
    );

    $mod1->parse_paras(
        \@synopsis_paras,
        'MyModule::Test - SYNOPSIS',
    );

=cut

sub parse_paras {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ($self, $paras, $msg) = @_;

    # Construct a large regex.
    my $regex =
        join '',
        map { $_.q{\n\n+} }
        map { (ref($_) eq 'HASH') ? $_->{re} : quotemeta($_) }
        @{$paras};

    return $self->parse( qr/$regex/ms, $msg );
}

sub format_msg {
    my ($self, $msg) = @_;

    return $msg;
}

=head2 $file_parser->parse_file_start

Parse the file based on the filename.  This will have various templates
on how to parse files of that type.

=cut

sub parse_file_start {
    my ($self) = @_;
    
    my $basefn  = basename($self->{fn});
    if ($basefn =~ /\.pm/) {
        return $self->parse_module_start() if (ref $self eq 'TestParseModuleFile');
        Carp::confess( "Wrong method for testing $basefn; use TestParseModuleFile" );
    }
    
    my $mainmod = $self->{modules}[0];
    my $minperl = $self->{minperl} || 5.006;
    
    my $has_eumm = (grep { /ExtUtils::MakeMaker/ } @{ $self->{builder} })[0];
    my $has_mb   = (grep { /Module::Build/       } @{ $self->{builder} })[0];
    my $has_mi   = (grep { /Module::Install/     } @{ $self->{builder} })[0];
    my $has_dzil = (grep { /Dist::Zilla/         } @{ $self->{builder} })[0];
    
    $self->{license_record} = $self->_license_record;
    (my $slname = ref $self->{license_record}) =~ s/Software::License:://;
    my $license_url = $self->{license_record}->url || $self->{license_record}->meta2_name || $slname;
    my $license_blurb = $self->{license_record}->notice();
    
    (my $author = "$self->{author} <$self->{email}>") =~ s/'/\'/g;
    (my $libmod = "lib/$mainmod".'.pm') =~ s|::|/|g;
    
    my $manifest_skip = $self->{ignores_type} && !! grep { /manifest/ } @{ $self->{ignores_type} };
    $manifest_skip ||= $has_dzil;
   
    if ($basefn =~ /\.pm/) {
        return $self->parse_module_start() if (ref $self eq 'TestParseModuleFile');
        Carp::confess( "Wrong method for testing $basefn; use TestParseModuleFile" );
    }
    
    my $msw_re  = qr{use \Q$minperl;\E\n\Quse strict;\E\n\Quse warnings FATAL => 'all';\E\n};
    my $mswt_re = qr{\A\Q#!perl -T\E\n$msw_re\Quse Test::More;\E\n\n};

    my @resources_txt = split /\n/, <<"EOT";
#homepage   => 'http://yourwebsitehere.com',
#IRC        => 'irc://irc.perl.org/#$self->{distro}',
license     => '$license_url',
repository  => {
   url  => 'git://github.com/$self->{author}/$self->{distro}.git',
   web  => 'http://github.com/$self->{author}/$self->{distro}',
   type => 'git',
},
bugtracker  => {
   web    => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=$self->{distro}',
   mailto => 'bug-$self->{distro}\@rt.cpan.org',
},
EOT
    
    if ($basefn eq 'Build.PL' && $has_mb) {
        plan tests => 12;
        $self->parse(qr{\A$msw_re\Quse Module::Build;\E\n\n},
            "Min/Strict/Warning/Builder"
        );

        $self->parse(qr{\A.*module_name *=> *'\Q$mainmod\E',\n}ms,
            "module_name",
        );

        $self->parse(qr{\A\s*license *=> *'$slname',\n}ms,
            "license",
        );

        $self->parse(qr{\A\s*dist_author *=> *\Qq{$author},\E\n}ms,
            "dist_author",
        );

        $self->parse(qr{\A\s*dist_version_from *=> *\Q'$libmod',\E\n}ms,
            "dist_version_from",
        );

        $self->parse(qr{\A\s*release_status *=> *\Q'stable',\E\n}ms,
            "release_status",
        );

        $self->parse(
            qr/\A\s*configure_requires => \{\n *\Q'$has_mb' => 0\E,\n\s*\},\n/ms,
            "Configure Requires",
        );

        $self->parse(
            qr/\A\s*build_requires => \{\n *\Q'Test::More' => 0\E,\n\s*\},\n/ms,
            "Build Requires",
        );

        $self->parse(
            qr/\A\s*requires => \{\n *\Q#'ABC'\E *\Q=> 1.6,\E\n *\Q#'Foo::Bar::Module' => 5.0401,\E\n\s*\},\n/ms,
            "Requires",
        );

        $self->consume("    resources => {\n        ".
                                    join("\n        ", @resources_txt)."\n".
                       "    },\n", 'resources');

        $self->parse(
            qr/\A\s*add_to_cleanup *=> \Q[ '$self->{distro}-*' ],\E\n/ms,
            "add_to_cleanup",
        );

        $self->parse(
            qr/\A\s*create_makefile_pl *=> \Q'traditional',\E\n/ms,
            "create_makefile_pl",
        );
    }
    elsif ($basefn eq 'Makefile.PL' && $has_eumm) {
        plan tests => 12;
        $self->parse(qr{\A$msw_re\Quse ExtUtils::MakeMaker;\E\n\n},
            "Min/Strict/Warning/Builder"
        );

        $self->parse(qr{\A.*NAME *=> *'$mainmod',\n}ms,
            "NAME",
        );

        $self->parse(qr{\A\s*AUTHOR *=> *\Qq{$author},\E\n}ms,
            "AUTHOR",
        );

        $self->parse(qr{\A\s*VERSION_FROM *=> *\Q'$libmod',\E\n}ms,
            "VERSION_FROM",
        );

        $self->parse(qr{\A\s*ABSTRACT_FROM *=> *\Q'$libmod',\E\n}ms,
            "ABSTRACT_FROM",
        );

        $self->parse(qr{\A\s*LICENSE *=> *\Q'$slname',\E\n}ms,
            "LICENSE",
        );

        $self->parse(qr{\A\s*PL_FILES *=> *\{\},\n}ms,
            "PL_FILES",
        );

        $self->parse(qr{\A\s*MIN_PERL_VERSION *=> *\Q$minperl,\E\n}ms,
            "MIN_PERL_VERSION",
        );
        
        $self->parse(
            qr/\A\s*CONFIGURE_REQUIRES => \{\n *\Q'$has_eumm' => 0\E,\n\s*\},\n/ms,
            "CONFIGURE_REQUIRES",
        );

        $self->parse(
            qr/\A\s*BUILD_REQUIRES => \{\n *\Q'Test::More' => 0\E,\n\s*\},\n/ms,
            "BUILD_REQUIRES",
        );

        $self->parse(
            qr/\A\s*PREREQ_PM => \{\n *\Q#'ABC'\E *\Q=> 1.6,\E\n *\Q#'Foo::Bar::Module' => 5.0401,\E\n\s*\},\n/ms,
            "PREREQ_PM",
        );
            
        $self->consume("    META_ADD => {\n".
                       "        resources => {\n            ".
                                        join("\n            ", @resources_txt)."\n".
                       "        },\n".
                       "    },\n", 'resources');

    }
    elsif ($basefn eq 'Makefile.PL' && $has_mi) {
        plan tests => 13;
        $self->parse(qr{\A$msw_re\Quse inc::Module::Install;\E\n\n},
            "Min/Strict/Warning/Builder"
        );

        $self->parse(qr{\Aname\s+\Q'$self->{distro}';\E\n}ms,
            "name",
        );

        $self->parse(qr{\Aall_from\s+\Q'$libmod';\E\n}ms,
            "all_from",
        );

        $self->parse(qr{\Aauthor\s+\Qq{$author};\E\n}ms,
            "author",
        );

        $self->parse(qr{\Alicense\s+\Q'$slname';\E\n\n}ms,
            "license",
        );

        $self->parse(qr{\Aperl_version\s+\Q$minperl;\E\n\n}ms,
            "perl_version",
        );

        $self->parse(qr{\A\Qtests_recursive('t');\E\n\n}ms,
            "tests_recursive",
        );
        
        $self->consume("resources (\n   ".
                             join("\n   ", @resources_txt)."\n".
                       ");\n\n", 'resources');
        
        $self->parse(
            qr/\A\s*configure_requires \(\n *\Q'$has_mi' => 0\E,\n\s*\);\n/ms,
            "configure_requires",
        );

        $self->parse(
            qr/\A\s*build_requires \(\n *\Q'Test::More' => 0\E,\n\s*\);\n/ms,
            "build_requires",
        );

        $self->parse(
            qr/\A\s*requires \(\n *\Q#'ABC'\E *\Q=> 1.6,\E\n *\Q#'Foo::Bar::Module' => 5.0401,\E\n\s*\);\n/ms,
            "requires",
        );

        $self->consume(<<"EOF", 'Footer');

install_as_cpan;
auto_install;
WriteAll;
EOF

        $self->is_end();
    }
    elsif ($basefn eq 'dist.ini' && $has_dzil) {
        plan tests => 2;

        my $license_holder = $self->{license_record}->holder();
        my $license_year   = $self->{license_record}->year();

        $self->consume(<<"EOF");
name    = $self->{distro}
author  = $author
license = $self->{license}
copyright_holder = $license_holder
copyright_year   = $license_year

version = 0.01

[\@Basic]
[InstallGuide]
[ReadmeAnyFromPod / HtmlInRoot]
[MetaJSON]

[MetaResources]
;homepage         = http://yourwebsitehere.com
;IRC              = irc://irc.perl.org/#$self->{distro}
license           = $license_url
repository.url    = git://github.com/$self->{author}/$self->{distro}.git
repository.web    = http://github.com/$self->{author}/$self->{distro}
repository.type   = git
bugtracker.web    = http://rt.cpan.org/NoAuth/Bugs.html?Dist=$self->{distro}
bugtracker.mailto = bug-$self->{distro}\@rt.cpan.org

[PodWeaver]

[KwaliteeTests]
[NoTabsTests]
[EOLTests]
[Signature]

[CheckChangeLog]

[\@Git]

[AutoPrereqs]
;skip = ^Foo|Bar$

[Prereq / TestRequires]
Dist::Zilla = 0
Test::More  = 0
EOF

        $self->is_end();
    }
    elsif ($basefn eq 'Changes') {
        plan tests => 2;

        $self->consume(<<"EOF");
Revision history for $self->{distro}

0.01    Date/time
        First version, released on an unsuspecting world.

EOF

        $self->is_end();
    }
    elsif ($basefn eq 'MANIFEST' && !$manifest_skip) {
        plan tests => 2;
        
        $self->consume(join("\n", 
            ('Build.PL') x!! $has_mb,
            'Changes',
            ( map { my $f = $_; $f =~ s|::|/|g; "lib/$f.pm"; } @{$self->{modules}} ),
            'LICENSE',
            ('Makefile.PL') x!! ($has_eumm || $has_mi),
            "MANIFEST\t\t\tThis list of files",
            qw(
                README
                t/00-load.t
                t/manifest.t
                t/pod-coverage.t
                t/pod.t
            )
        )."\n");

        $self->is_end();
    }
    elsif ($basefn eq 'MANIFEST.SKIP' && $manifest_skip) {
        plan tests => 2;
        $self->consume(<<'EOF');
# Top-level filter (only include the following...)
^(?!(?:script|examples|lib|inc|t|xt|maint)/|(?:(?:Makefile|Build)\.PL|README|MANIFEST|Changes|META\.(?:yml|json))$)

# Avoid version control files.
\bRCS\b
\bCVS\b
,v$
\B\.svn\b
\b_darcs\b
# (.git only in top-level, hence it's blocked above)

# Avoid temp and backup files.
~$
\.tmp$
\.old$
\.bak$
\..*?\.sw[po]$
\#$
\b\.#

# avoid OS X finder files
\.DS_Store$

# ditto for Windows
\bdesktop\.ini$
\b[Tt]humbs\.db$

# Avoid patch remnants
\.orig$
\.rej$
EOF

        $self->is_end();
    }
    elsif ($basefn =~ /^(?:ignore\.txt|\.(?:cvs|git)ignore)$/) {
        plan tests => ($manifest_skip ? 3 : 2);

        $self->consume("MANIFEST\nMANIFEST.bak\n", 'MANIFEST*') if ($manifest_skip);
        $self->consume(<<"EOF");
Makefile
Makefile.old
Build
Build.bat
META.*
MYMETA.*
.build/
_build/
cover_db/
blib/
inc/
.lwpcookies
.last_cover_stats
nytprof.out
pod2htm*.tmp
pm_to_blib
$self->{distro}-*
$self->{distro}-*.tar.gz
EOF
        $self->is_end();
    }
    elsif ($basefn eq 'README') {
        plan tests => 6;
        $self->parse(qr{\A\Q$self->{distro}\E\n\n}ms,
            "Starts with the package name",
        );

        $self->parse(qr{\AThe README is used to introduce the module and provide instructions.*?\n\n}ms,
            "README used to introduce",
        );

        $self->parse(
            qr{\AA README file is required for CPAN modules since CPAN extracts the.*?\n\n\n}ms,
            "A README file is required",
        );

        ### XXX: This could be anything for multiple builders... ###
        # my $install_instr = $self->{builder} eq 'Module::Build' ?
            # qr{\Qperl Build.PL\E\n\s+\Q./Build\E\n\s+\Q./Build test\E\n\s+\Q./Build install\E} :
            # qr{\Qperl Makefile.PL\E\n\s+\Qmake\E\n\s+\Qmake test\E\n\s+\Qmake install\E};

        $self->parse(qr{\A\n*INSTALLATION\n\nTo install this module, run the following commands:\n\n\s+.+?\n\n}s,
            "INSTALLATION section",
        );

        $self->parse(qr{\ASUPPORT AND DOCUMENTATION\n\nAfter installing.*?^\s+perldoc \Q$mainmod\E\n\n}ms,
            "Support and docs 1"
        );

        $self->parse(qr{\AYou can also look for information at:\n\n\s+RT[^\n]+\n\s+\Qhttp://rt.cpan.org/NoAuth/Bugs.html?Dist=$self->{distro}\E\n\n}ms,
            "RT"
        );
    }
    elsif ($basefn eq 'LICENSE') {
        plan tests => 2;
        $self->consume( $self->{license_record}->license() );
        $self->is_end();
    }
    elsif ($basefn eq '00-load.t') {
        my $cnt = scalar @{$self->{modules}};
        plan tests => $cnt + 4;

        $self->parse($mswt_re,
            "#!perl/Min/Strict/Warning/Test::More"
        );

        $self->consume(<<"EOH", 'Plan Header');
plan tests => $cnt;

BEGIN {
EOH
        foreach my $module (@{$self->{modules}}) {
            $self->consume(<<"EOM", $module);
    use_ok( '$module' ) || print "Bail out!\\n";
EOM
        }
        
        my $escape_version = '$'.$mainmod.'::VERSION';
        $self->consume(<<"EOF", 'Footer');
}

diag( "Testing $mainmod $escape_version, Perl \$], \$^X" );
EOF

        $self->is_end();
    }
    elsif ($basefn eq 'boilerplate.t') {
        my $cnt = scalar @{$self->{modules}} + 2;
        plan tests => $cnt + 3;

        $self->parse($mswt_re,
            "#!perl/Min/Strict/Warning/Test::More"
        );

        $self->consume(<<"EOH", 'Plan Header');
plan tests => $cnt;

EOH

        $self->consume(<<'EOT', 'Sub declares');
sub not_in_file_ok {
    my ($filename, %regex) = @_;
    open( my $fh, '<', $filename )
        or die "couldn't open $filename for reading: $!";

    my %violated;

    while (my $line = <$fh>) {
        while (my ($desc, $regex) = each %regex) {
            if ($line =~ $regex) {
                push @{$violated{$desc}||=[]}, $.;
            }
        }
    }

    if (%violated) {
        fail("$filename contains boilerplate text");
        diag "$_ appears on lines @{$violated{$_}}" for keys %violated;
    } else {
        pass("$filename contains no boilerplate text");
    }
}

sub module_boilerplate_ok {
    my ($module) = @_;
    not_in_file_ok($module =>
        'the great new $MODULENAME'   => qr/ - The great new /,
        'boilerplate description'     => qr/Quick summary of what the module/,
        'stub function definition'    => qr/function[12]/,
    );
}

TODO: {
  local $TODO = "Need to replace the boilerplate text";

  not_in_file_ok(README =>
    "The README is used..."       => qr/The README is used/,
    "'version information here'"  => qr/to provide version information/,
  );

  not_in_file_ok(Changes =>
    "placeholder date/time"       => qr(Date/time)
  );
EOT
        foreach my $module (@{$self->{modules}}) {
            (my $modre = 'lib::'.$module.'\.pm') =~ s|::|'[:/]'|ge;  # only : for Mac, and / for all others (including Windows)
            $self->parse(qr{\A\s*module_boilerplate_ok\(\'$modre\'\)\;\n}, $module);
        }
        
        $self->parse(qr{\A\s*\}\s*}ms, 'Footer');

        $self->is_end();
    }
    elsif ($basefn eq 'manifest.t') {
        plan tests => 3;

        $self->parse($mswt_re,
            "#!perl/Min/Strict/Warning/Test::More"
        );

        my $minimal_test_checkmanifest = '0.9';
        $self->consume(<<"EOF");
unless ( \$ENV{RELEASE_TESTING} ) {
    plan( skip_all => "Author tests not required for installation" );
}

my \$min_tcm = $minimal_test_checkmanifest;
eval "use Test::CheckManifest \$min_tcm";
plan skip_all => "Test::CheckManifest \$min_tcm required" if \$\@;

ok_manifest();
EOF

        $self->is_end();
    }
    elsif ($basefn eq 'pod.t') {
        plan tests => 3;

        $self->parse($mswt_re,
            "#!perl/Min/Strict/Warning/Test::More"
        );

        my $minimal_test_pod = "1.22";
        $self->consume(<<"EOF");
# Ensure a recent version of Test::Pod
my \$min_tp = $minimal_test_pod;
eval "use Test::Pod \$min_tp";
plan skip_all => "Test::Pod \$min_tp required for testing POD" if \$\@;

all_pod_files_ok();
EOF

        $self->is_end();
    }
    elsif ($basefn eq 'pod-coverage.t') {
        plan tests => 5;

        $self->parse($mswt_re,
            "#!perl/Min/Strict/Warning/Test::More"
        );

        my $l1 = q{eval "use Test::Pod::Coverage $min_tpc";};

        $self->parse(
            qr/\A# Ensure a recent[^\n]+\nmy \$min_tpc = \d+\.\d+;\n\Q$l1\E\nplan skip_all[^\n]+\n *if \$\@;\n\n/ms,
            'min_tpc block',
        );

        $l1 = q{eval "use Pod::Coverage $min_pc";};

        $self->parse(
            qr/\A(?:# [^\n]+\n)*my \$min_pc = \d+\.\d+;\n\Q$l1\E\nplan skip_all[^\n]+\n *if \$\@;\n\n/ms,
            'min_pod_coverage block',
        );

        $self->parse(
            qr/all_pod_coverage_ok\(\);\n/,
            'all_pod_coverage_ok',
        );

        $self->is_end();
    }
    else {
        $self->_diag;
        Carp::confess( "No testing template for $basefn" );
    }

    done_testing();
    return;
}

package TestParseModuleFile;

use parent qw(-norequire TestParseFile);

sub parse_module_start {
    my $self = shift;

    my $perl_name    = $self->{module};
    my $dist_name    = $self->{distro};
    my $author_name  = $self->{author};
    my $lc_dist_name = lc($dist_name);
    my $minperl      = $self->{minperl} || 5.006;
    
    Test::More::plan tests => 19;

    $self->parse(
        qr/\Apackage \Q$perl_name\E;\n\nuse $minperl;\nuse strict;\n\Quse warnings FATAL => 'all';\E\n\n/ms,
        'start',
    );

    {
        my $s1 = qq{$perl_name - The great new $perl_name!};

        $self->parse(
            qr/\A=head1 NAME\n\n\Q$s1\E\n\n/ms,
            "NAME Pod.",
        );
    }

    $self->parse(
        qr/\A=head1 VERSION\n\nVersion 0\.01\n\n=cut\n\nour \$VERSION = '0\.01';\n+/,
        "module version",
    );

    {
        my @synopsis_paras =
        (
            '=head1 SYNOPSIS',
            'Quick summary of what the module does.',
            'Perhaps a little code snippet.',
            { re => q{\s*} . quotemeta(qq{use $perl_name;}), },
            { re => q{\s*} .
                quotemeta(q{my $foo = } . $perl_name . q{->new();})
                . q{\n\s*} . quotemeta('...'),
            },
        );

        $self->parse_paras(
            \@synopsis_paras,
            'SYNOPSIS',
        );
    }

    $self->parse_paras(
        [
            '=head1 EXPORT',
              "A list of functions that can be exported.  You can delete this section\n"
            . "if you don't export anything, such as for a purely object-oriented module.",
        ],
        "EXPORT",
    );

    $self->parse_paras(
        [
            "=head1 SUBROUTINES/METHODS",
            "=head2 function1",
            "=cut",
            "sub function1 {\n}",
        ],
        "function1",
    );

    $self->parse_paras(
        [
            "=head2 function2",
            "=cut",
            "sub function2 {\n}",
        ],
        "function2",
    );

    $self->parse_paras(
        [
            "=head1 AUTHOR",
            { re => quotemeta($author_name) . q{[^\n]+} },
        ],
        "AUTHOR",
    );

    $self->parse_paras(
        [
            "=head1 BUGS",
            { re =>
                  q/Please report any bugs.*C<bug-/
                . quotemeta($lc_dist_name)
                .  q/ at rt\.cpan\.org>.*changes\./
            },
        ],
        "BUGS",
    );

    $self->parse_paras(
        [
            "=head1 SUPPORT",
            { re => q/You can find documentation for this module.*/ },
            { re => q/\s+perldoc / . quotemeta($perl_name), },
            "You can also look for information at:",
            "=over 4",
        ],
        "Support 1",
    );

    $self->parse_paras(
        [
            { re => q/=item \* RT:[^\n]*/, },
            "L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=$dist_name>",
        ],
        "Support - RT",
    );


    $self->parse_paras(
        [
            { re => q/=item \* AnnoCPAN:[^\n]*/, },
            "L<http://annocpan.org/dist/$dist_name>",
        ],
        "AnnoCPAN",
    );

    $self->parse_paras(
        [
            { re => q/=item \* CPAN Ratings[^\n]*/, },
            "L<http://cpanratings.perl.org/d/$dist_name>",
        ],
        "CPAN Ratings",
    );

    $self->parse_paras(
        [
            { re => q/=item \* Search CPAN[^\n]*/, },
            "L<http://search.cpan.org/dist/$dist_name/>",
        ],
        "CPAN Ratings",
    );

    $self->parse_paras(
        [
            "=back",
        ],
        "Support - =back",
    );

    $self->parse_paras(
        [
            "=head1 ACKNOWLEDGEMENTS",
        ],
        "acknowledgements",
    );

    $self->parse_paras(
        [
            "=head1 LICENSE AND COPYRIGHT",
            split(/\n\n+/, $self->_license_record->notice() ),
        ],
        "copyright",
    );

    $self->parse_paras(
        [
            "=cut",
        ],
        "=cut POD end",
    );

    $self->consume(
        qq{1; # End of $perl_name},
        "End of module",
    );

    return;
}


package main;

use File::Find;

# Since we are going into randomization with tests, seed saving is now important.
# rand calls srand automatically, then we re-seed.  Perl 5.14 would allow us to 
# just get the seed value from a srand() call, but we aren't there yet...
my $random_seed = int(rand() * 2**32);
srand($random_seed);

sub run_settest {
    my ($base_dir, $distro_var) = @_;
    my $module_base_dir = File::Spec->catdir(qw(t data), ref $base_dir ? @$base_dir : $base_dir);
    $distro_var->{dir} = $module_base_dir;
    
    subtest 'Set ==> '.$distro_var->{modules}[0] => sub {
        Module::Starter->create_distro( %$distro_var );
        
        $distro_var->{__srand} = $random_seed;

        my $has_eumm = (grep { /ExtUtils::MakeMaker/ } @{ $distro_var->{builder} })[0];
        my $has_mb   = (grep { /Module::Build/       } @{ $distro_var->{builder} })[0];
        my $has_mi   = (grep { /Module::Install/     } @{ $distro_var->{builder} })[0];
        my $has_dzil = (grep { /Dist::Zilla/         } @{ $distro_var->{builder} })[0];
        
        my $manifest_skip = $distro_var->{ignores_type} && !! grep { /manifest/ } @{ $distro_var->{ignores_type} };
        
        my @exist_files = (
            (qw(README LICENSE)) x! $has_dzil,
            'Changes',
            ($manifest_skip ? 'MANIFEST.SKIP' : $has_dzil ? () : 'MANIFEST'),
            ('Build.PL')    x!! $has_mb,
            ('Makefile.PL') x!! ($has_eumm || $has_mi),
            ('dist.ini')    x!! $has_dzil,
            [qw(t 00-load.t)],
            [qw(t boilerplate.t)],
            [qw(t manifest.t)],
            [qw(t pod.t)],
            [qw(t pod-coverage.t)],
        );
        
        # Make sure we are actually testing every single file
        my @test_files;
        my $base_cnt = scalar File::Spec->splitdir($module_base_dir);
        find({
            no_chdir => 1,
            wanted => sub {
                -f and do {
                    my @dirs = File::Spec->splitdir($_);
                    @dirs = splice(@dirs, $base_cnt);  # delete base_dir
                    return if ($dirs[0] eq 'lib' && $dirs[-1] =~ /\.pm$/);
                    
                    push(@test_files,
                        @dirs == 1 ? $dirs[0] : \@dirs
                    );
                };
            }
        }, $module_base_dir);
        
        plan tests => (@exist_files + @test_files + @{$distro_var->{modules}});
        
        # File existence tests
        foreach my $arrfile (@exist_files) {
            my $file = ref $arrfile ? File::Spec->catfile(@$arrfile) : $arrfile;
            ok(-f File::Spec->catfile($module_base_dir, $file), "Exists: $file")
               or diag explain $distro_var;
        }

        # Standard file tests
        foreach my $arrfile (@test_files) {
            my $file = ref $arrfile ? File::Spec->catfile(@$arrfile) : $arrfile;
            subtest $file => sub {
                TestParseFile->new(
                    { fn => File::Spec->catfile($module_base_dir, $file), %$distro_var }
                )->parse_file_start();
            };
        }
        
        # Module tests
        foreach my $module (@{$distro_var->{modules}}) {
            subtest $module => sub {
                TestParseModuleFile->new({
                    fn => File::Spec->catfile($module_base_dir, 'lib', split(/::/, "$module.pm")),
                    module => $module,
                    %$distro_var
                })->parse_module_start();
            };
        }

        rmtree $module_base_dir unless ($ENV{'DONT_DEL_TEST_DIST'});
    };
}

my @rand_char = split //, '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_';
sub rstr {
    my $str = '';
    my $len = int(rand(20)) + 1;
    $str .= $rand_char[ int(rand(@rand_char)) ] for (1 .. $len);
    return $str;
}
sub rstr_array {
    my @str;
    my $len = int(rand(5)) + 1;
    push(@str, rstr) for (1 .. $len);
    return @str;
}
sub rstr_module {
    my @str;
    my $len = int(rand(5)) + 1;
    push(@str, rstr) for (1 .. $len);
    
    while ($str[0] =~ /^\d+/) {
        $str[0] =~ s/^\d+//;
        shift @str unless ($str[0]);
        return &rstr_module unless (@str);
    }
    
    return join('::', @str);
}

plan tests => 5;

my $DONT_DEL = $ENV{'DONT_DEL_TEST_DIST'};
run_settest('MyModule-Test', {
    distro  => 'MyModule-Test',
    modules => ['MyModule::Test', 'MyModule::Test::App'],
    builder => ['Module::Install'],
    license => 'artistic',
    author  => 'Baruch Spinoza',
    email   => 'spinoza@philosophers.tld',
    verbose => 0,
    force   => $DONT_DEL,    
});

run_settest('Book-Park-Mansfield', {
    distro  => 'Book-Park-Mansfield',
    modules => [
        'Book::Park::Mansfield',
        'Book::Park::Mansfield::Base',
        'Book::Park::Mansfield::FannyPrice',
        'JAUSTEN::Utils',
    ],
    builder => ['Module::Install'],
    license => 'artistic',
    author  => 'Jane Austen',
    email   => 'jane.austen@writers.tld',
    verbose => 0,
    force   => $DONT_DEL,
});

### Test all variations of everything ###

# Figure out which S::L are already installed and put them on the list
note "Loading ExtUtils::Installed...";
use ExtUtils::Installed;
my $eui = ExtUtils::Installed->new();
my @licenses = grep { !/^Custom$/ } grep { s/^.+Software\WLicense\W(\w+).pm$/$1/; } $eui->files('Software::License', 'prog');
push(@licenses, grep { s/^Software::License:://; } ( $eui->modules() ));

note "TTL_TESTS = ".(my $TTL_TESTS = (15-4) * @licenses * 5 * 16 * 2);

# See which builders we have available
my %EVAL_BUILDER;
foreach my $builder (qw(ExtUtils::MakeMaker Module::Build Module::Install Dist::Zilla)) {
    $EVAL_BUILDER{$builder} = eval "require $builder; 1;"  # require hates string class names; must use eval string instead of block
}

foreach my $bt (1..15) {
next if ($bt & 1+4);  # EUMM+MI wouldn't mesh too well...
my $builder = [
    ('ExtUtils::MakeMaker') x!! ($bt & 1),
    ('Module::Build')       x!! ($bt & 2),
    ('Module::Install')     x!! ($bt & 4),
    ('Dist::Zilla')         x!! ($bt & 8),
];
subtest "builder = ".join(' ', @$builder) => sub {
    foreach my $bdr (@$builder) { plan skip_all => $builder.' not installed' unless ($EVAL_BUILDER{$bdr}); }
    plan tests => scalar @licenses;

    foreach my $license (sort @licenses) {
    subtest "license = $license" => sub {
        plan tests => 5;

        foreach my $minperl (5.006, 5.008001, v5.10.0, 'v5.10.1', $^V) {
        subtest "minperl = ".(ref \$minperl eq 'VSTRING' ? sprintf('v%vd', $minperl) : $minperl) => sub {
            plan ($minperl > $^V ? 
                (skip_all => $minperl.' is actually newer than Perl version ($^V)') : 
                (tests => 16)
            );
            
            foreach my $it (0..15) {
            my $ignores_type = [
                ('generic')  x!! ($it & 1),
                ('cvs')      x!! ($it & 2),
                ('git')      x!! ($it & 4),
                ('manifest') x!! ($it & 8),
            ];
            subtest "ignores_type = ".join(' ', @$ignores_type) => sub {
                # Only run through a small sample of these tests, since there's so many combinations
                # (But, always do both force tests.)
                plan ((rand() > 5/$TTL_TESTS*100) ?  # try to keep it at around 5-10 tests total
                    (skip_all => sprintf('Only testing a %.4f%% sample', 5/$TTL_TESTS*100)) : 
                    (tests => 2)
                );

                # This stuff should always be the same for both force tests.
                # Force tests should always been last (innermost) in the loop as well.
                my $self->{distro} = join('-', rstr_array);
                my $author = rstr.' '.rstr;
                my $email  = join('.', rstr_array).'@'.join('.', rstr_array).'.tld';

                my @modules;
                my $len = int(rand(20)) + 1;
                push(@modules, rstr_module ) for (1 .. $len);
                @modules = sort {
                    # match the sorting to exactly what the MANIFEST lists would look like
                    my ($q, $r) = ($a, $b);
                    $q =~ s|::|/|g;
                    $r =~ s|::|/|g;
                    return lc $q cmp lc $r;
                } @modules;
                
                foreach my $force (0, 1) {
                subtest "force = $force" => sub {
                    $ENV{'DONT_DEL_TEST_DIST'} = !$force || $DONT_DEL;
                    
                    run_settest(['loop', $self->{distro}], {  # store these in its own directory
                        distro  => $self->{distro},
                        modules => \@modules,
                        builder => $builder,
                        license => $license,
                        author  => $author,
                        email   => $email,
                        minperl => $minperl,
                        verbose => 0,
                        force   => $force,
                        ignores_type => $ignores_type,
                    });
                    
                }; }
            }; }
        }; }
    }; }
}; }

$ENV{'DONT_DEL_TEST_DIST'} = $DONT_DEL;
my $loop_dir = File::Spec->catdir(qw(t data loop));
rmtree $loop_dir if (-d $loop_dir && !$DONT_DEL);

1;

=head1 NAME

t/test-dist.t - test the integrity of prepared distributions.

=head1 AUTHOR

Shlomi Fish, L<http://www.shlomifish.org/>
Heavy revamp by Brendan Byrd, L<BBYRD@CPAN.org>
