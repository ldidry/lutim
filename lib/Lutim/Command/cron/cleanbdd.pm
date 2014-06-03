package Lutim::Command::cron::cleanbdd;
use Mojo::Base 'Mojolicious::Command';
use LutimModel;
use Mojo::Util qw(slurp decode);

has description => 'Delete IP addresses from database after configured delay.';
has usage => sub { shift->extract_usage };

sub run {
    my $c = shift;

    my $config = $c->app->plugin('ConfigHashMerge', {
        default => {
            keep_ip_during => 365,
        }
    });

    my $separation = time() - $config->{keep_ip_during} * 86400;

    LutimModel->do(
        'UPDATE lutim SET created_by = "" WHERE path IS NOT NULL AND created_at < ?',
        {},
        $separation
    );
}

=encoding utf8

=head1 NAME

Lutim::Command::cron::cleanbdd - Delete IP addresses from database after configured delay

=head1 SYNOPSIS

  Usage: script/lutim cron cleanbdd

=cut

1;
