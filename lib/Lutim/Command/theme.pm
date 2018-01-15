# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lutim::Command::theme;
use Mojo::Base 'Mojolicious::Commands';
use FindBin qw($Bin);
use File::Spec qw(catfile cat dir);
use File::Path qw(make_path);

has description => 'Create new theme skeleton.';
has usage => sub { shift->extract_usage };
has message    => sub { shift->extract_usage . "\nCreate new theme skeleton:\n" };
has namespaces => sub { ['Lutim::Command::theme'] };

sub run {
    my $c    = shift;
    my $name = shift;

    unless (defined $name) {
        say $c->extract_usage;
        exit 1;
    }

    my $home = File::Spec->catdir($Bin, '..', 'themes', $name);

    unless (-d $home) {

        # Create skeleton
        mkdir $home;
        mkdir File::Spec->catdir($home, 'public');
        make_path(File::Spec->catdir($home, 'templates', 'layouts'));
        make_path(File::Spec->catdir($home, 'lib', 'Lutim', 'I18N'));

        my $i18n = <<EOF;
# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lutim::I18N;

use base 'Locale::Maketext';
use File::Basename qw/dirname/;
use Locale::Maketext::Lexicon {
    _auto => 1,
    _decode => 1,
    _style  => 'gettext',
    '*' => [
        Gettext => dirname(__FILE__) . '/I18N/*.po',
        Gettext => dirname(__FILE__) . '/../../../default/lib/Lutim/I18N/*.po',
    ]
};

1;
EOF

        open my $f, '>', File::Spec->catfile($home, 'lib', 'Lutim', 'I18N.pm') or die "Unable to open $home/lib/Lutim/I18N.pm: $!";
        print $f $i18n;
        close $f;

        my $makefile = <<EOF;
EN=lib/Lutim/I18N/en.po
FR=lib/Lutim/I18N/fr.po
DE=lib/Lutim/I18N/de.po
ES=lib/Lutim/I18N/es.po
OC=lib/Lutim/I18N/oc.po
AR=lib/Lutim/I18N/ar.po
SEDOPTS=-e "s\@SOME DESCRIPTIVE TITLE\@Lutim language file\@" \\
		-e "s\@YEAR THE PACKAGE'S COPYRIGHT HOLDER\@2015 Luc Didry\@" \\
		-e "s\@CHARSET\@utf8\@" \\
		-e "s\@the PACKAGE package\@the Lutim package\@" \\
		-e '/^\\#\\. (/{N;/\\n\\#\\. (/{N;/\\n.*\\.\\.\\/default\\//{s/\\#\\..*\\n.*\\#\\./\\#. (/g}}}' \\
		-e '/^\\#\\. (/{N;/\\n.*\\.\\.\\/default\\//{s/\\n/ /}}' 
SEDOPTS2=-e '/^\\#.*\\.\\.\\/default\\//,+3d'
XGETTEXT=carton exec ../../local/bin/xgettext.pl
CARTON=carton exec

locales:
		\$(XGETTEXT) -D templates -D ../default/templates -o \$(EN) 2>/dev/null
		\$(XGETTEXT) -D templates -D ../default/templates -o \$(FR) 2>/dev/null
		\$(XGETTEXT) -D templates -D ../default/templates -o \$(DE) 2>/dev/null
		\$(XGETTEXT) -D templates -D ../default/templates -o \$(ES) 2>/dev/null
		\$(XGETTEXT) -D templates -D ../default/templates -o \$(OC) 2>/dev/null
		\$(XGETTEXT) -D templates -D ../default/templates -o \$(AR) 2>/dev/null
		sed \$(SEDOPTS) -i \$(EN)
		sed \$(SEDOPTS2) -i \$(EN)
		sed \$(SEDOPTS) -i \$(FR)
		sed \$(SEDOPTS2) -i \$(FR)
		sed \$(SEDOPTS) -i \$(DE)
		sed \$(SEDOPTS2) -i \$(DE)
		sed \$(SEDOPTS) -i \$(ES)
		sed \$(SEDOPTS2) -i \$(ES)
		sed \$(SEDOPTS) -i \$(OC)
		sed \$(SEDOPTS) -i \$(OC)
		sed \$(SEDOPTS2) -i \$(AR)
		sed \$(SEDOPTS2) -i \$(AR)
EOF

        open $f, '>', File::Spec->catfile($home, 'Makefile') or die "Unable to open $home/Makefile: $!";
        print $f $makefile;
        close $f;
        open $f, '>', File::Spec->catfile($home, '.gitignore') or die "Unable to open $home/.gitignore: $!";
        print $f "public/packed/\ntemplates/data.html.ep";
        close $f;
    } else {
        say "$name theme already exists. Aborting.";
        exit 1;
    }
}

=encoding utf8

=head1 NAME

Lutim::Command::theme - Create new theme skeleton.

=head1 SYNOPSIS

  Usage: script/lutim theme THEME_NAME

  Your new theme will be available in the themes directory.
=cut

1;
