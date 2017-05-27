# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lutim::Command::cron::watch;
use Mojo::Base 'Mojolicious::Command';
use Mojo::Util qw(slurp decode);
use Filesys::DiskUsage qw/du/;
use Lutim::DB::Image;
use Lutim;
use Switch;
use FindBin qw($Bin);
use File::Spec qw(catfile);

has description => 'Watch the files directory and take action when over quota';
has usage => sub { shift->extract_usage };

sub run {
    my $c = shift;

    my $config = $c->app->plugin('Config', {
        file    => File::Spec->catfile($Bin, '..' ,'lutim.conf'),
        default => {
            policy_when_full => 'warn',
            dbtype           => 'sqlite',
        }
    });

    if (defined($config->{max_total_size})) {
        my $total = du(qw/files/);

        if ($total > $config->{max_total_size}) {
            say "[Lutim cron job watch] Files directory is over quota ($total > ".$config->{max_total_size}.")";
            switch ($config->{policy_when_full}) {
                case 'warn' {
                    say "[Lutim cron job watch] Please, delete some files or increase quota (".$config->{max_total_size}.")";
                }
                case 'stop-upload' {
                    open (my $fh, '>', 'stop-upload') or die ("Couldn't open stop-upload: $!");
                    close($fh);
                    say '[Lutim cron job watch] Uploads are stopped. Delete some images and the stop-upload file to reallow uploads.';
                }
                case 'delete' {
                    say '[Lutim cron job watch] Older files are being deleted';
                    my $dbi = Lutim::DB::Image->new(app => $c->app);
                    my $l = Lutim->new;
                    do {
                        $dbi->get_50_oldest()->each(
                            sub {
                                my ($img, $num) = @_;
                                $l->app->delete_image($img);
                            }
                        );
                    } while (du(qw/files/) > $config->{max_total_size});
                }
                else {
                    say '[Lutim cron job watch] Unrecognized policy_when_full option: '.$config->{policy_when_full}.'. Aborting.';
                }
            }
        } else {
            unlink 'stop-upload' if (-f 'stop-upload');
        }
    } else {
        say "[Lutim cron job watch] No max_total_size found in the configuration file. Aborting.";
    }
}

=encoding utf8

=head1 NAME

Lutim::Command::cron::watch - Watch the files directory and take action when over quota

=head1 SYNOPSIS

  Usage: script/lutim cron watch

=cut

1;
