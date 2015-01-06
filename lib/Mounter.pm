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
                url_sub_dir => '/'
            }
        }
    );

    $self->plugin('Mount' => {$config->{url_sub_dir} => File::Spec->catfile($Bin, '..', 'script', 'application')});
}

1;
