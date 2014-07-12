package Lutim;
use Mojo::Base 'Mojolicious';
use Mojo::Util qw(quote);
use LutimModel;
use Crypt::CBC;

$ENV{MOJO_TMPDIR} = 'tmp';
mkdir($ENV{MOJO_TMPDIR}, 0700) unless (-d $ENV{MOJO_TMPDIR});
# This method will run once at server start
sub startup {
    my $self = shift;

    push @{$self->commands->namespaces}, 'Lutim::Command';

    $self->{wait_for_it} = {};

    $self->plugin('I18N');
    $self->plugin('AssetPack');

    my $config = $self->plugin('ConfigHashMerge', {
        default => {
            provisioning     => 100,
            provis_step      => 5,
            length           => 8,
            always_encrypt   => 0,
            anti_flood_delay => 5,
            tweet_card_via   => '@framasky',
            max_file_size    => 10*1024*1024,
            https            => 0,
            default_delay    => 0,
            max_delay        => 0,
            token_length     => 24,
        }
    });

    # Default values
    $config->{provisioning}     = $config->{provisionning} if (defined($config->{provisionning}));

    die "You need to provide a contact information in lutim.conf !" unless (defined($config->{contact}));

    $ENV{MOJO_MAX_MESSAGE_SIZE} = $config->{max_file_size};

    $self->secrets($config->{secrets});

    $self->helper(
        render_file => sub {
            my $c = shift;
            my ($filename, $path, $mediatype, $dl, $expires, $nocache, $key) = @_;

            $filename = quote($filename);

            my $asset;
            unless ( -f $path && -r _ ) {
                $c->app->log->error("Cannot read file [$path]. error [$!]");
                $c->flash(
                    msg => $c->l('image_not_found')
                );
                return 500;
            }

            $mediatype =~ s/x-//;

            my $headers = Mojo::Headers->new();
            if ($nocache) {
                $headers->add('Cache-Control'   => 'no-cache, no-store, max-age=0, must-revalidate');
            } else {
                $headers->add('Expires'         => $expires);
            }
            $headers->add('Content-Type'        => $mediatype.';name='.$filename);
            $headers->add('Content-Disposition' => $dl.';filename='.$filename);
            $c->res->content->headers($headers);

            $c->app->log->debug($key);
            if ($key) {
                $asset = $c->decrypt($key, $path);
            } else {
                $asset = Mojo::Asset::File->new(path => $path);
            }
            $c->res->content->asset($asset);
            $headers->add('Content-Length' => $asset->size);

            return $c->rendered(200);
        }
    );

    $self->helper(
        ip => sub {
            my $c  = shift;
            my $ip_only = shift || 0;

            my $proxy = $c->req->headers->header('X-Forwarded-For');

            my $ip = ($proxy) ? $proxy : $c->tx->remote_address;

            my $remote_port = (defined($c->req->headers->header('X-Remote-Port'))) ? $c->req->headers->header('X-Remote-Port') : $c->tx->remote_port;

            return ($ip_only) ? $ip : "$ip remote port:$remote_port";
        }
    );

    $self->helper(
        provisioning => sub {
            my $c = shift;

            # Create some short patterns for provisioning
            if (LutimModel::Lutim->count('WHERE path IS NULL') < $c->config->{provisioning}) {
                for (my $i = 0; $i < $c->config->{provis_step}; $i++) {
                    if (LutimModel->begin) {
                        my $short;
                        do {
                            $short= $c->shortener($c->config->{length});
                        } while (LutimModel::Lutim->count('WHERE short = ?', $short) || $short eq 'about' || $short eq 'stats' || $short eq 'd' || $short eq 'm');

                        LutimModel::Lutim->create(
                            short                => $short,
                            counter              => 0,
                            enabled              => 1,
                            delete_at_first_view => 0,
                            delete_at_day        => 0,
                            mod_token            => $c->shortener($c->config->{token_length})
                        );
                        LutimModel->commit;
                    }
                }
            }
        }
    );

    $self->helper(
        shortener => sub {
            my $c      = shift;
            my $length = shift;

            my @chars  = ('a'..'z','A'..'Z','0'..'9');
            my $result = '';
            foreach (1..$length) {
                $result .= $chars[rand scalar(@chars)];
            }
            return $result;
        }
    );

    $self->helper(
        stop_upload => sub {
            my $c = shift;

            if (-f 'stop-upload' || -f 'stop-upload.manual') {
                $c->stash(
                    stop_upload => $c->l('stop_upload', $config->{contact})
                );
                return 1;
            }
            return 0;
        }
    );

    $self->helper(
        max_delay => sub {
            my $c = shift;

            return $c->config->{max_delay} if ($c->config->{max_delay} >= 0);

            warn "max_delay set to a negative value. Default to 0.";
            return 0;
        }
    );

    $self->helper(
        default_delay => sub {
            my $c = shift;

            return $c->config->{default_delay} if ($c->config->{default_delay} >= 0);

            warn "default_delay set to a negative value. Default to 0.";
            return 0;
        }
    );

    $self->helper(
        is_selected => sub {
            my $c   = shift;
            my $num = shift;

            return ($num == $c->default_delay) ? 'selected="selected"' : '';
        }
    );

    $self->helper(
        crypt => sub {
            my $c        = shift;
            my $upload   = shift;
            my $filename = shift;

            my $key   = $c->shortener(8);

            my $cipher = Crypt::CBC->new(
                -key    => $key,
                -cipher => 'Blowfish',
                -header => 'none',
                -iv     => 'dupajasi'
            );

            $cipher->start('encrypting');

            my $crypt_asset = Mojo::Asset::File->new;

            $crypt_asset->add_chunk($cipher->crypt($upload->slurp));
            $crypt_asset->add_chunk($cipher->finish);

            my $crypt_upload = Mojo::Upload->new;
            $crypt_upload->filename($filename);
            $crypt_upload->asset($crypt_asset);

            return ($crypt_upload, $key);
        }
    );

    $self->helper(
        decrypt => sub {
            my $c    = shift;
            my $key  = shift;
            my $file = shift;

            my $cipher = Crypt::CBC->new(
                -key    => $key,
                -cipher => 'Blowfish',
                -header => 'none',
                -iv     => 'dupajasi'
            );

            $cipher->start('decrypting');

            my $decrypt_asset = Mojo::Asset::File->new;

            open(my $f, "<",$file) or die "Unable to read encrypted file: $!";
            binmode $f;
            while (read($f, my $buffer,1024)) {
                  $decrypt_asset->add_chunk($cipher->crypt($buffer));
            }
            $decrypt_asset->add_chunk($cipher->finish) ;

            return $decrypt_asset;
        }
    );

    $self->helper(
        delete_image => sub {
            my $c = shift;
            my $image = shift;
            unlink $image->path();
            $image->update(enabled => 0);
        }
    );

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

    $self->asset('index.css' => 'css/bootstrap.min.css', 'css/fontello-embedded.css', 'css/animation.css', 'css/uploader.css', 'css/hennypenny.css', 'css/lutim.css');
    $self->asset('stats.css' => 'css/bootstrap.min.css', 'css/fontello-embedded.css', 'css/morris-0.4.3.min.css', 'css/hennypenny.css', 'css/lutim.css');
    $self->asset('about.css' => 'css/bootstrap.min.css', 'css/fontello-embedded.css', 'css/hennypenny.css', 'css/lutim.css');

    $self->asset('index.js' => 'js/jquery-2.1.0.min.js', 'js/bootstrap.min.js', 'js/lutim.js', 'js/dmuploader.min.js');
    $self->asset('stats.js' => 'js/jquery-2.1.0.min.js', 'js/bootstrap.min.js', 'js/lutim.js', 'js/raphael-min.js', 'js/morris-0.4.3.min.js', 'js/stats.js');

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

    $r->get('/stats')->
        to('Controller#stats')->
        name('stats');

    $r->get('/manifest.webapp')->
        to('Controller#webapp')->
        name('manifest.webapp');

    $r->post('/')->
        to('Controller#add')->
        name('add');

    $r->get('/d/:short/:token')->
        to('Controller#delete')->
        name('delete');

    $r->post('/m/:short/:token')->
        to('Controller#modify')->
        name('modify');

    $r->get('/:short')->
        to('Controller#short')->
        name('short');

    $r->get('/:short/:key')->
        to('Controller#short');
}

1;
