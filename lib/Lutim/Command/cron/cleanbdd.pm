# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lutim::Command::cron::cleanbdd;
use Mojo::Base 'Mojolicious::Command';
use Lutim::DB::Image;
use Mojo::File;
use FindBin qw($Bin);
use File::Spec qw(catfile);

has description => 'Delete IP addresses from database after configured delay.';
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
            keep_ip_during => 365,
            dbtype         => 'sqlite',
        }
    });

    my $separation = time() - $config->{keep_ip_during} * 86400;

    my $dbi = Lutim::DB::Image->new(app => $c->app);

    $dbi->clean_ips_until($separation);
}

=encoding utf8

=head1 NAME

Lutim::Command::cron::cleanbdd - Delete IP addresses from database after configured delay

=head1 SYNOPSIS

  Usage: script/lutim cron cleanbdd

=cut

1;
