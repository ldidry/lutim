# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lutim::Plugin::Lang;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Collection;
use Mojo::File;

sub register {
    my ($self, $app) = @_;

    $app->helper(available_langs => \&_available_langs);

    $app->hook(
        before_dispatch => sub {
            my $c = shift;
            $c->languages($c->cookie('lutim_lang')) if $c->cookie('lutim_lang');
        }
    );
}

sub _available_langs {
    my $c = shift;

    state $langs = Mojo::Collection->new(
        glob($c->app->home->rel_file('themes/'.$c->config('theme').'/lib/Lutim/I18N/*po')),
        glob($c->app->home->rel_file('themes/default/lib/Lutim/I18N/*po'))
    )->map(
        sub {
            Mojo::File->new($_)->basename('.po');
        }
    )->uniq->sort(
        sub {
            $c->l($a) cmp $c->l($b)
        }
    )->to_array;
}

1;

