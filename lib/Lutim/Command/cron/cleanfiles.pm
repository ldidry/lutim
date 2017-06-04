# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lutim::Command::cron::cleanfiles;
use Mojo::Base 'Mojolicious::Command';
use Mojo::Util qw(slurp decode);
use Lutim::DB::Image;
use Lutim;
use Mojo::File;
use FindBin qw($Bin);
use File::Spec qw(catfile);

has description => 'Delete expired files.';
has usage => sub { shift->extract_usage };

sub run {
    my $c = shift;

    my $cfile = Mojo::File->new($Bin, '..' , 'lutim.conf');
    if (defined $ENV{MOJO_CONFIG}) {
        $cfile = Mojo::File->new($ENV{MOJO_CONFIG});
        unless (-e $cfile->to_abs) {
            $cfile = Mojo::File->new($Bin, '..', $ENV{MOJO_CONFIG});
        }
    }
    my $config = $c->app->plugin('Config', {
        file    => $cfile,
        default => {
            dbtype => 'sqlite',
        }
    });

    my $l = Lutim->new;

    my $dbi = Lutim::DB::Image->new(app => $c->app);

    $dbi->get_images_to_clean()->each(
        sub {
            my ($img, $num) = @_;
            $l->app->delete_image($img);
        }
    );

    if (defined($config->{delete_no_longer_viewed_files}) && $config->{delete_no_longer_viewed_files} > 0) {
        my $time = time() - $config->{delete_no_longer_viewed_files} * 86400;
        $dbi->get_no_longer_viewed_files($time)->each(
            sub {
                my ($img, $num) = @_;
                $l->app->delete_image($img);
            }
        );
    }
}

=encoding utf8

=head1 NAME

Lutim::Command::cron::cleanfiles - Delete expired files

=head1 SYNOPSIS

  Usage: script/lutim cron cleanfiles

=cut

1;
