package Lutim;
use Mojo::Base 'Mojolicious';
use Mojo::Util qw(quote);
use LutimModel;
use Crypt::CBC;
use Data::Entropy qw(entropy_source);

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
        }
    });

    die "You need to provide a contact information in lutim.conf !" unless (defined($config->{contact}));

    $ENV{MOJO_MAX_MESSAGE_SIZE} = $config->{max_file_size};

    $self->secrets($config->{secrets});

    # Themes handling
    shift @{$self->renderer->paths};
    shift @{$self->static->paths};
    if ($config->{theme} ne 'default') {
        my $theme = $self->home->child('themes', $config->{theme});
        push @{$self->renderer->paths}, $theme.'/templates' if -d $theme.'/templates';
        push @{$self->static->paths}, $theme.'/public' if -d $theme.'/public';
    }
    push @{$self->renderer->paths}, $self->home->child('themes', 'default', 'templates');
    push @{$self->static->paths}, $self->home->child('themes', 'default', 'public');
    # Internationalization
    my $lib = $self->home->child('themes', $config->{theme}, 'lib');
    eval qq(use lib "$lib");
    $self->plugin('I18N');

    # Compressed assets
    $self->plugin('AssetPack' => { pipes => [qw(Combine)] });

    # Helpers
    $self->helper(
        render_file => sub {
            my $c = shift;
            my ($filename, $path, $mediatype, $dl, $expires, $nocache, $key, $thumb) = @_;

            $dl       = 'attachment' if ($mediatype =~ m/svg/);
            $filename = quote($filename);

            my $asset;
            unless (-f $path && -r $path) {
                $c->app->log->error("Cannot read file [$path]. error [$!]");
                $c->flash(
                    msg => $c->l('Unable to find the image: it has been deleted.')
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

            if ($key) {
                $asset = $c->decrypt($key, $path);
            } else {
                $asset = Mojo::Asset::File->new(path => $path);
            }

            if (defined $thumb && $im_loaded && $mediatype ne 'image/svg+xml' && $mediatype !~ m#image/(x-)?xcf# && $mediatype ne 'image/webp') { # ImageMagick don't work in Debian with svg (for now?)
                my $im  = Image::Magick->new;
                $im->BlobToImage($asset->slurp);

                # Create the thumbnail
                $im->Resize(geometry=>'x'.$c->config('thumbnail_size'));

                # Replace the asset with the thumbnail
                $asset = Mojo::Asset::Memory->new->add_chunk($im->ImageToBlob());
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
                        } while (LutimModel::Lutim->count('WHERE short = ?', $short) || $short eq 'about' || $short eq 'stats' || $short eq 'd' || $short eq 'm' || $short eq 'gallery' || $short eq 'zip' || $short eq 'infos');

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
                $result .= $chars[entropy_source->get_int(scalar(@chars))];
            }
            return $result;
        }
    );

    $self->helper(
        stop_upload => sub {
            my $c = shift;

            if (-f 'stop-upload' || -f 'stop-upload.manual') {
                $c->stash(
                    stop_upload => $c->l('Uploading is currently disabled, please try later or contact the administrator (%1).', $config->{contact})
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

            my $key   = $c->shortener($c->config('crypto_key_length'));

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
