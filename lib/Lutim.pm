# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lutim;
use Mojo::Base 'Mojolicious';
use Mojo::IOLoop;
use Lutim::DB::Image;
use Lutim::DefaultConfig qw($default_config);

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

    push @{$self->commands->namespaces}, 'Lutim::Command';

    $self->plugin('DebugDumperHelper');

    my $config = $self->plugin('Config', {
        default => $default_config
    });

    if ($config->{watermark_path}) {
        die sprintf('%s does not exist or is not readable.', $config->{watermark_path}) unless -r $config->{watermark_path};
        my $valid = {
            center    => 1,
            north     => 1,
            northeast => 1,
            east      => 1,
            southeast => 1,
            south     => 1,
            southwest => 1,
            west      => 1,
            northwest => 1
        };
        die sprintf('%s is not a valid value for watermark_placement.', $config->{watermark_placement}) unless $valid->{lc($config->{watermark_placement})};
        $valid = {
            'tiling' => 1,
            'single' => 1,
            'none'   => 1
        };
        die sprintf('%s is not a valid value for watermark_default.', $config->{watermark_default}) unless $valid->{lc($config->{watermark_default})};
        die sprintf('%s is not a valid value for watermark_enforce.', $config->{watermark_enforce}) unless $valid->{lc($config->{watermark_enforce})};
    }

    if (scalar(@{$config->{memcached_servers}})) {
        $self->plugin(CHI => {
            lutim_images_cache => {
                driver             => 'Memcached',
                servers            => $config->{memcached_servers},
                expires_in         => '1 day',
                expires_on_backend => 1,
            }
        });
    } elsif ($config->{cache_max_size} != 0) {
        my $cache_max_size = 8 * 1024 * 1024 * $config->{cache_max_size};
        $self->plugin(CHI => {
            lutim_images_cache => {
                driver        => 'Memory',
                global        => 1,
                is_size_aware => 1,
                max_size      => $cache_max_size,
                expires_in    => '1 day'
            }
        });
    }

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

    # Static assets gzipping
    $self->plugin('GzipStatic');

    # Headers
    $self->plugin('Lutim::Plugin::Headers');

    # Helpers
    $self->plugin('Lutim::Plugin::Helpers');
    $self->plugin('Lutim::Plugin::Lang');

    # Minion
    if ($config->{minion}->{enabled}) {
        $self->config->{minion}->{dbtype} = 'sqlite' unless defined $config->{minion}->{dbtype};
        if ($config->{minion}->{dbtype} eq 'sqlite') {
            $config->{minion}->{db_path} = 'minion.db' unless defined $config->{minion}->{db_path};
            $self->plugin('Minion' => { SQLite => 'sqlite:'.$config->{minion}->{db_path} });
        } elsif ($config->{minion}->{dbtype} eq 'postgresql') {
            $self->plugin('PgURLHelper');
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

    # Authentication (if configured)
    if (defined($config->{ldap}) || defined($config->{htpasswd})) {
        if (defined($config->{ldap})) {
            require Net::LDAP;
        }
        if (defined($config->{htpasswd})) {
            require Apache::Htpasswd;
        }
        die sprintf('Unable to read %s', $config->{htpasswd}) if (defined($config->{htpasswd}) && !-r $config->{htpasswd});
        $self->plugin('Authentication' =>
            {
                autoload_user => 1,
                session_key   => 'Lutim',
                load_user     => sub {
                    my ($c, $username) = @_;

                    return $username;
                },
                validate_user => sub {
                    my ($c, $username, $password, $extradata) = @_;

                    if (defined($c->config('ldap'))) {
                        my $ldap = Net::LDAP->new($c->config->{ldap}->{uri});

                        my $mesg;
                        if (defined($c->config->{ldap}->{bind_dn}) && defined($c->config->{ldap}->{bind_pwd})) {
                            # connect to the ldap server using the bind credentials
                            $mesg = $ldap->bind(
                                $c->config->{ldap}->{bind_dn},
                                password => $c->config->{ldap}->{bind_pwd}
                            );
                        } else {
                            # anonymous bind
                            $mesg = $ldap->bind
                        }

                        if ($mesg->code) {
                            $c->app->log->info('[LDAP INFO] Authenticated bind failed - Login: '.$c->config->{ldap}->{bind_dn}) if defined($c->config->{ldap}->{bind_dn});
                            $c->app->log->error('[LDAP ERROR] Error on bind: '.$mesg->error);
                            return undef;
                        }

                        my $ldap_user_attr   = $c->config->{ldap}->{user_attr};
                        my $ldap_user_filter = $c->config->{ldap}->{user_filter};

                        # search the ldap database for the user who is trying to login
                        $mesg = $ldap->search(
                            base   => $c->config->{ldap}->{user_tree},
                            filter => "(&($ldap_user_attr=$username)$ldap_user_filter)"
                        );

                        if ($mesg->code) {
                            $c->app->log->error('[LDAP ERROR] Error on search: '.$mesg->error);
                            return undef;
                        }

                        # check to make sure that the ldap search returned at least one entry
                        my @entries = $mesg->entries;
                        my $entry   = $entries[0];

                        unless (defined $entry) {
                            $c->app->log->info("[LDAP INFO] Authentication failed - User $username filtered out, IP: ".$c->ip);
                            return undef;
                        }

                        # retrieve the first user returned by the search
                        $c->app->log->debug("[LDAP DEBUG] Found user dn: ".$entry->dn);

                        # Now we know that the user exists
                        $mesg = $ldap->bind($entry->dn,
                            password => $password
                        );

                        if ($mesg->code) {
                            $c->app->log->info("[LDAP INFO] Authentication failed - Login: $username, IP: ".$c->ip);
                            $c->app->log->error('[LDAP ERROR] Authentication failed '.$mesg->error);
                            return undef;
                        }

                        $c->app->log->info("[LDAP INFO] Authentication successful - Login: $username, IP: ".$c->ip);
                    } elsif (defined($c->config('htpasswd'))) {
                        my $htpasswd = new Apache::Htpasswd(
                            {
                                passwdFile => $c->config('htpasswd'),
                                ReadOnly   => 1
                            }
                        );
                        if (!$htpasswd->htCheckPassword($username, $password)) {
                            return undef;
                        }
                        $c->app->log->info("[Simple authentication successful] login: $username, IP: ".$c->ip);
                    }

                    return $username;
                }
            }
        );
        $self->app->sessions->default_expiration($config->{session_duration});
    }

    $self->defaults(layout => 'default');

    $self->provisioning();

    # Router
    my $r = $self->routes;

    $r->add_condition(authorized => sub {
        my ($r, $c, $captures) = @_;

        return 1 unless (defined($config->{ldap}) || defined($config->{htpasswd}));

        return $c->is_user_authenticated;
    });

    $r->options(sub {
        my $c = shift;
        $c->res->headers->allow('POST') if (defined($c->config->{allowed_domains}));
        $c->render(data => '', status => 204);
    });

    $r->get('/')->
        requires('authorized')->
        to('Image#home')->
        name('index');
    $r->get('/')->
        to('Authent#index');


    if (defined $config->{ldap} || defined $config->{htpasswd}) {
        # Login page
        $r->get('/login')
            ->to('Authent#index')
            ->name('login');

        # Authentication
        $r->post('/login')
            ->to('Authent#login');

        # Logout page
        $r->get('/logout')
            ->to('Authent#log_out')
            ->name('logout');
    }

    $r->get('/about')->
        to('Image#about')->
        name('about');

    $r->get('/infos')->
        to('Image#infos')->
        name('infos');

    $r->get('/stats')->
        to('Image#stats')->
        name('stats');

    $r->get('/lang/:l')->
        to('Image#change_lang')->
        name('lang');

    $r->get('/partial/<:file>.<:f>' => sub {
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

    $r->get('/myfiles')->
        requires('authorized')->
        name('myfiles');
    $r->get('/myfiles')->
        to('Authent#index');

    $r->get('/manifest.webapp')->
        to('Image#webapp')->
        name('manifest.webapp');

    $r->get('/zip')
        ->to('Image#zip')
        ->name('zip');

    $r->get('/random')
        ->to('Image#random')
        ->name('random');

    $r->post('/')->
        requires('authorized')->
        to('Image#add')->
        name('add');
    $r->post('/')->
        to('Authent#index');

    $r->get('/d/:short/:token')->
        requires('authorized')->
        to('Image#delete')->
        name('delete');
    $r->get('/d/:short/:token')->
        to('Authent#index');

    $r->post('/m/:short/:token')->
        requires('authorized')->
        to('Image#modify')->
        name('modify');
    $r->post('/m/:short/:token')->
        to('Authent#index');

    $r->post('/c')->
        requires('authorized')->
        to('Image#get_counter')->
        name('counter');
    $r->post('/c')->
        to('Authent#index');

    $r->get('/about/<:short>')->
        to('Image#about_img')->
        name('about_img');

    $r->get('/about/<:short>.<:f>')->
        to('Image#about_img')->
        name('about_img');

    $r->get('/about/:short/<:key>.<:f>')->
        to('Image#about_img')->
        name('about_img');

    $r->get('/<:short>.<:f>')->
        to('Image#short')->
        name('short');

    $r->get('/:short')->
        to('Image#short');

    $r->get('/:short/<:key>.<:f>')->
        to('Image#short');

    $r->get('/:short/:key')->
        to('Image#short');
}

1;
