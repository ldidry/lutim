# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lutim;
use Mojo::Base 'Mojolicious';
use Lutim::DB::Image;

use vars qw($im_loaded);
BEGIN {
    eval "use Image::Magick";
    if ($@) {
        warn "You don't have Image::Magick installed so you won't have thumbnails.";
        $im_loaded = 0;
    } else {
        $im_loaded = 1;
    }
}

$ENV{MOJO_TMPDIR} = 'tmp';
mkdir($ENV{MOJO_TMPDIR}, 0700) unless (-d $ENV{MOJO_TMPDIR});
# This method will run once at server start
sub startup {
    my $self = shift;

    $self->{wait_for_it} = {};

    $self->plugin('DebugDumperHelper');

    my $config = $self->plugin('Config', {
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
        }
    });

    die "You need to provide a contact information in lutim.conf !" unless (defined($config->{contact}));

    $ENV{MOJO_MAX_MESSAGE_SIZE} = $config->{max_file_size};

    $self->secrets($config->{secrets});

    # Themes handling
    shift @{$self->renderer->paths};
    shift @{$self->static->paths};
    if ($config->{theme} ne 'default') {
        my $theme = $self->home->rel_file('themes/'.$config->{theme});
        push @{$self->renderer->paths}, $theme.'/templates' if -d $theme.'/templates';
        push @{$self->static->paths}, $theme.'/public' if -d $theme.'/public';
    }
    push @{$self->renderer->paths}, $self->home->rel_file('themes/default/templates');
    push @{$self->static->paths}, $self->home->rel_file('themes/default/public');
    # Internationalization
    my $lib = $self->home->rel_file('themes/'.$config->{theme}.'/lib');
    eval qq(use lib "$lib");
    $self->plugin('I18N');

    # Compressed assets
    $self->plugin('AssetPack' => { pipes => [qw(Combine)] });

    # Helpers
    $self->plugin('Lutim::Plugin::Helpers');

    # Hooks
    $self->hook(
        before_dispatch => sub {
            my $c = shift;
            $c->stop_upload();

            # API allowed domains
            if (defined($c->config->{allowed_domains})) {
                if ($c->config->{allowed_domains}->[0] eq '*') {
                    $c->res->headers->header('Access-Control-Allow-Origin' => '*');
                } elsif (my $origin = $c->req->headers->origin) {
                    for my $domain ($c->config->{allowed_domains}) {
                        if ($domain->[0] eq $origin) {
                            $c->res->headers->header('Access-Control-Allow-Origin' => $origin);
                            last;
                        }
                    }
                }
            }

            # Scheme detection
            if ((defined($c->req->headers->header('X-Forwarded-Proto')) && $c->req->headers->header('X-Forwarded-Proto') eq 'https') || $c->config->{https}) {
                $c->req->url->base->scheme('https');
            }
        }
    );

    $self->hook(
        after_dispatch => sub {
            my $c = shift;
            $c->provisioning();

            # Purge expired anti-flood protection
            my $wait_for_it = $c->app->{wait_for_it};
            delete @{$wait_for_it}{grep { time - $wait_for_it->{$_} > $c->config->{anti_flood_delay} } keys %{$wait_for_it}} if (defined($wait_for_it));
        }
    );

    $self->asset->store->paths($self->static->paths);
    $self->asset->process('index.css' => ('css/bootstrap.min.css', 'css/fontello-embedded.css', 'css/animation.css', 'css/uploader.css', 'css/hennypenny.css', 'css/lutim.css', 'css/markdown.css'));
    $self->asset->process('stats.css' => ('css/bootstrap.min.css', 'css/fontello-embedded.css', 'css/morris-0.4.3.min.css', 'css/hennypenny.css', 'css/lutim.css'));
    $self->asset->process('about.css' => ('css/bootstrap.min.css', 'css/fontello-embedded.css', 'css/hennypenny.css', 'css/lutim.css'));

    $self->asset->process('index.js'  => ('js/jquery-2.1.0.min.js', 'js/bootstrap.min.js', 'js/lutim.js', 'js/dmuploader.min.js'));
    $self->asset->process('stats.js'  => ('js/jquery-2.1.0.min.js', 'js/bootstrap.min.js', 'js/lutim.js', 'js/raphael-min.js', 'js/morris-0.4.3.min.js', 'js/stats.js'));
    $self->asset->process('freeze.js' => ('js/jquery-2.1.0.min.js', 'js/freezeframe.min.js'));

    $self->defaults(layout => 'default');

    $self->provisioning();

    # Router
    my $r = $self->routes;

    $r->options(sub {
        my $c = shift;
        $c->res->headers->allow('POST') if (defined($c->config->{allowed_domains}));
        $c->render(data => '', status => 204);
    });

    $r->get('/')->
        to('Controller#home')->
        name('index');

    $r->get('/about')->
        to('Controller#about')->
        name('about');

    $r->get('/infos')->
        to('Controller#infos')->
        name('infos');

    $r->get('/stats')->
        to('Controller#stats')->
        name('stats');

    $r->get('/gallery' => sub {
        shift->render(
            template => 'gallery',
        );
    })->name('gallery');

    $r->get('/myfiles' => sub {
        shift->render(
            template => 'myfiles'
        );
    })->name('myfiles');

    $r->get('/manifest.webapp')->
        to('Controller#webapp')->
        name('manifest.webapp');

    $r->get('/zip')
        ->to('Controller#zip')
        ->name('zip');

    $r->post('/')->
        to('Controller#add')->
        name('add');

    $r->get('/d/:short/:token')->
        to('Controller#delete')->
        name('delete');

    $r->post('/m/:short/:token')->
        to('Controller#modify')->
        name('modify');

    $r->post('/c')->
        to('Controller#get_counter')->
        name('counter');

    $r->get('/(:short).(:f)')->
        to('Controller#short')->
        name('short');
    $r->get('/:short')->
        to('Controller#short');

    $r->get('/:short/(:key).(:f)')->
        to('Controller#short');
    $r->get('/:short/:key')->
        to('Controller#short');
}

1;
