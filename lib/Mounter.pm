# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Mounter;
use Mojo::Base 'Mojolicious';
use Mojo::File;
use FindBin qw($Bin);
use File::Spec qw(catfile);

# This method will run once at server start
sub startup {
    my $self = shift;

    push @{$self->commands->namespaces}, 'Lutim::Command';

    my $cfile = Mojo::File->new($Bin, '..' , 'lutim.conf');
    if (defined $ENV{MOJO_CONFIG}) {
        $cfile = Mojo::File->new($ENV{MOJO_CONFIG});
        unless (-e $cfile->to_abs) {
            $cfile = Mojo::File->new($Bin, '..', $ENV{MOJO_CONFIG});
        }
    }
    my $config = $self->plugin('Config' =>
        {
            file    => $cfile,
            default => {
                provisioning      => 100,
                provis_step       => 5,
                length            => 8,
                always_encrypt    => 0,
                anti_flood_delay  => 5,
                tweet_card_via    => '@framasky',
                max_file_size     => 10*1024*1024,
                https             => 0,
                default_delay     => 0,
                max_delay         => 0,
                token_length      => 24,
                crypto_key_length => 8,
                thumbnail_size    => 100,
                theme             => 'default',
                dbtype            => 'sqlite',
                max_files_in_zip  => 15,
                prefix            => '/',
                minion            => {
                    enabled => 0,
                    dbtype  => 'sqlite',
                    db_path => 'minion.db'
                },
            }
        }
    );

    $config->{prefix} = $config->{url_sub_dir} if (defined($config->{url_sub_dir}) && $config->{prefix} eq '/');

    $self->app->log->warn('"url_sub_dir" configuration option is deprecated. Use "prefix" instead. "url_sub_dir" will be removed in the future') if (defined($config->{url_sub_dir}));

    # Themes handling
    shift @{$self->static->paths};
    if ($config->{theme} ne 'default') {
        my $theme = $self->home->rel_file('themes/'.$config->{theme});
        push @{$self->static->paths}, $theme.'/public' if -d $theme.'/public';
    }
    push @{$self->static->paths}, $self->home->rel_file('themes/default/public');

    # Cache static files
    $self->plugin('StaticCache');

    # Helpers
    $self->plugin('Lutim::Plugin::Helpers');

    $self->plugin('Mount' => {$config->{prefix} => File::Spec->catfile($Bin, '..', 'script', 'application')});
}

1;
