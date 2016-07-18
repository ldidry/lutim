package Mounter;
use Mojo::Base 'Mojolicious';
use FindBin qw($Bin);
use File::Spec qw(catfile);

# This method will run once at server start
sub startup {
    my $self = shift;

    push @{$self->commands->namespaces}, 'Lutim::Command';

    my $config = $self->plugin('Config' =>
        {
            file    => File::Spec->catfile($Bin, '..' ,'lutim.conf'),
            default => {
                prefix => '/',
                theme  => 'default',
            }
        }
    );

    $config->{prefix} = $config->{url_sub_dir} if (defined($config->{url_sub_dir}) && $config->{prefix} eq '/');

    $self->app->log->warn('"url_sub_dir" configuration option is deprecated. Use "prefix" instead. "url_sub_dir" will be removed in the future') if (defined($config->{url_sub_dir}));

    # Themes handling
    shift @{$self->static->paths};
    if ($config->{theme} ne 'default') {
        my $theme = $self->home->rel_dir('themes/'.$config->{theme});
        push @{$self->static->paths}, $theme.'/public' if -d $theme.'/public';
    }
    push @{$self->static->paths}, $self->home->rel_dir('themes/default/public');

    $self->plugin('Mount' => {$config->{prefix} => File::Spec->catfile($Bin, '..', 'script', 'application')});
}

1;
