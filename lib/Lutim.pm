# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lutim;
use Mojo::Base 'Mojolicious';
use Mojo::IOLoop;
use Lutim::DB::Image;
use CHI;

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
    $self->plugin('PgURLHelper');

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
            proposed_delays   => '0,1,7,30,365',
            default_delay     => 0,
            max_delay         => 0,
            token_length      => 24,
            crypto_key_length => 8,
            thumbnail_size    => 100,
            theme             => 'default',
            dbtype            => 'sqlite',
            db_path           => 'lutim.db',
            max_files_in_zip  => 15,
            prefix            => '/',
            minion            => {
                enabled => 0,
                dbtype  => 'sqlite',
                db_path => 'minion.db'
            },
            cache_max_size    => 0,
        }
    });

    my $cache_max_size = ($config->{cache_max_size} > 0) ? 8 * 1024 * 1024 * $config->{cache_max_size} : 1;
    $self->{images_cache} = CHI->new(
        driver        => 'Memory',
        servers       => [ "127.0.0.1:11211" ],
        global        => 1,
        is_size_aware => 1,
        max_size      => $cache_max_size,
        expires_in    => '1 day'
    );

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

    # Cache static files
    $self->plugin('StaticCache');

    # Helpers
    $self->plugin('Lutim::Plugin::Helpers');
    $self->plugin('Lutim::Plugin::Lang');

    # Minion
    if ($config->{minion}->{enabled}) {
        $self->config->{minion}->{dbtype} = 'sqlite' unless defined $config->{minion}->{dbtype};
        if ($config->{minion}->{dbtype} eq 'sqlite') {
            $self->config('minion')->{db_path} = 'minion.db' unless defined $config->{minion}->{db_path};
            $self->plugin('Minion' => { SQLite => 'sqlite:'.$config->{minion}->{db_path} });
        } elsif ($config->{minion}->{dbtype} eq 'postgresql') {
            $self->plugin('Minion' => { Pg => $self->pg_url($config->{minion}->{'pgdb'}) });
        }
        $self->app->minion->add_task(
            accessed => sub {
                my $job   = shift;
                my $short = $job->args->[0];
                my $time  = $job->args->[1];

                my $img = Lutim::DB::Image->new(app => $job->app, short => $short);
                $img->accessed($time) if $img->path;
            }
        );
    }

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

    # Recurrent tasks
    Mojo::IOLoop->recurring(5 => sub {
        my $loop = shift;

        $self->provisioning();

        # Purge expired anti-flood protection
        my $wait_for_it = $self->{wait_for_it};
        delete @{$wait_for_it}{grep { time - $wait_for_it->{$_} > $self->config->{anti_flood_delay} } keys %{$wait_for_it}} if (defined($wait_for_it));
    });

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

    $r->get('/lang/:l')->
        to('Controller#change_lang')->
        name('lang');

    $r->get('/partial/:file' => sub {
        my $c = shift;
        $c->render(
            template => 'partial/'.$c->param('file'),
            format   => 'js',
            layout   => undef,
            d        => {
                delay_0   => $c->l('no time limit'),
                delay_1   => $c->l('24 hours'),
                delay_365 => $c->l('1 year')
            }
        );
    })->name('partial');

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

    $r->get('/about/(:short).(:f)')->
        to('Controller#about_img')->
        name('about_img');

    $r->get('/about/:short/(:key).(:f)')->
        to('Controller#about_img')->
        name('about_img');

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
