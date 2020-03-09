# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lutim::Plugin::Helpers;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Util qw(quote);
use Mojo::File;
use Crypt::CBC;
use Data::Entropy qw(entropy_source);
use DateTime;
use Mojo::Util qw(decode);
use ISO::639_1;

sub register {
    my ($self, $app) = @_;


    if ($app->config('dbtype') eq 'postgresql') {
        require Mojo::Pg;
        $app->plugin('PgURLHelper');
        $app->helper(pg => \&_pg);

        # Database migration
        my $migrations = Mojo::Pg::Migrations->new(pg => $app->pg);
        if ($app->mode eq 'development' && $ENV{LUTIM_DEBUG}) {
            $migrations->from_file('utilities/migrations/postgresql.sql')->migrate(0)->migrate(3);
        } else {
            $migrations->from_file('utilities/migrations/postgresql.sql')->migrate(3);
        }
    } elsif ($app->config('dbtype') eq 'sqlite') {
        # SQLite database migration if needed
        require Mojo::SQLite;
        $app->helper(sqlite => \&_sqlite);

        my $sql = Mojo::SQLite->new('sqlite:'.$app->config('db_path'));
        my $migrations = $sql->migrations;
        if ($app->mode eq 'development' && $ENV{LUTIM_DEBUG}) {
            $migrations->from_file('utilities/migrations/sqlite.sql')->migrate(0)->migrate(2);
        } else {
            $migrations->from_file('utilities/migrations/sqlite.sql')->migrate(2);
        }
    }

    $app->helper(render_file        => \&_render_file);
    $app->helper(ip                 => \&_ip);
    $app->helper(provisioning       => \&_provisioning);
    $app->helper(shortener          => \&_shortener);
    $app->helper(stop_upload        => \&_stop_upload);
    $app->helper(max_delay          => \&_max_delay);
    $app->helper(default_delay      => \&_default_delay);
    $app->helper(is_selected        => \&_is_selected);
    $app->helper(is_wm_selected     => \&_is_wm_selected);
    $app->helper(crypt              => \&_crypt);
    $app->helper(decrypt            => \&_decrypt);
    $app->helper(delete_image       => \&_delete_image);
    $app->helper(iso639_native_name => \&_iso639_native_name);
    $app->helper(prefix             => \&_prefix);
}

sub _pg {
    my $c     = shift;

    state $pg = Mojo::Pg->new($c->app->pg_url($c->app->config('pgdb')));
    return $pg;
}

sub _sqlite {
    my $c     = shift;

    state $sqlite = Mojo::SQLite->new('sqlite:'.$c->app->config('db_path'));
    return $sqlite;
}

sub _render_file {
    my $c = shift;
    my ($im_loaded, $img, $dl, $key, $thumb) = @_;

    my ($filename, $path, $iv, $mediatype, $no_cache) = ($img->filename, $img->path, $img->iv, $img->mediatype, $img->delete_at_first_view);

    my $expires = ($img->delete_at_day) ? $img->delete_at_day : 360;
    my $dt = DateTime->from_epoch( epoch => $expires * 86400 + $img->created_at);
    $dt->set_time_zone('GMT');
    $expires = $dt->strftime("%a, %d %b %Y %H:%M:%S GMT");

    $dl       = 'attachment' if ($mediatype =~ m/svg/);
    $filename = quote($filename);

    unless (-f $path && -r $path) {
        $c->app->log->error("Cannot read file [$path]. error [$!]");
        $c->flash(
            msg => $c->l('Unable to find the image: it has been deleted.')
        );
        return 500;
    }

    $mediatype =~ s/x-//;

    my $headers = Mojo::Headers->new();
    if ($no_cache || defined($thumb)) {
        $headers->add('Cache-Control'   => 'no-cache, no-store, max-age=0, must-revalidate');
    } else {
        $headers->add('Expires'         => $expires);
    }
    $headers->add('Content-Type'        => $mediatype.';name='.$filename);
    $headers->add('Content-Disposition' => $dl.';filename='.$filename);
    $c->res->content->headers($headers);

    my $cache;
    if ($c->config('cache_max_size') != 0 || scalar(@{$c->config('memcached_servers')})) {
        $cache = $c->chi('lutim_images_cache')->compute($img->short, undef, sub {
            if ($key) {
                return {
                    asset => $c->decrypt($key, $path, $iv),
                    key   => $key
                };
            } else {
                return {
                    asset => Mojo::File->new($path)->slurp,
                };
            }
        });
        if ($key && $key ne $cache->{key}) {
            my $tmp = $c->decrypt($key, $path, $iv);
            $cache->{asset} = $tmp;
            $c->chi('lutim_images_cache')->replace(
                $img->short,
                {
                    asset => $tmp,
                    key   => $key
                },
            );
        }
    } else {
        if ($key) {
            $cache = {
                asset => $c->decrypt($key, $path, $iv),
            };
        } else {
            $cache = {
                asset => Mojo::File->new($path)->slurp,
            };
        }
    }
    # Extend expiration time
    my $asset = Mojo::Asset::Memory->new;
    $asset->add_chunk($cache->{asset});

    if (defined $thumb && $im_loaded && $mediatype ne 'image/svg+xml' && $mediatype !~ m#image/(x-)?xcf# && $mediatype ne 'image/webp') { # ImageMagick don't work in Debian with svg (for now?)
        my $im  = Image::Magick->new;
        $im->BlobToImage($asset->slurp);

        # Create the thumbnail
        if ($thumb eq '') {
            $im->Resize(geometry => 'x'.$c->config('thumbnail_size'));
        } else {
            $im->Resize(geometry => $thumb);
        }

        # Replace the asset with the thumbnail
        $asset = Mojo::Asset::Memory->new->add_chunk($im->ImageToBlob());
    }

    $c->res->content->asset($asset);
    $headers->add('Content-Length' => $asset->size);

    return $c->rendered(200);
}

sub _ip {
    my $c  = shift;
    my $ip_only = shift || 0;

    my $proxy = $c->req->headers->header('X-Forwarded-For');

    my $ip = ($proxy) ? $proxy : $c->tx->remote_address;

    my $remote_port = (defined($c->req->headers->header('X-Remote-Port'))) ? $c->req->headers->header('X-Remote-Port') : $c->tx->remote_port;

    return ($ip_only) ? $ip : "$ip remote port:$remote_port";
}

sub _provisioning {
    my $c = shift;

    # Create some short patterns for provisioning
    my $img = Lutim::DB::Image->new(app => $c->app);
    if ($img->count_empty < $c->app->config('provisioning')) {
        for (my $i = 0; $i < $c->app->config('provis_step'); $i++) {
            my $short;
            do {
                $short = $c->shortener($c->app->config('length'));
            } while ($img->count_short($short) || $short eq 'about' || $short eq 'stats' || $short eq 'd' || $short eq 'm' || $short eq 'gallery' || $short eq 'zip' || $short eq 'infos');

            $img->short($short)
                ->counter(0)
                ->enabled(1)
                ->delete_at_first_view(0)
                ->delete_at_day(0)
                ->mod_token($c->shortener($c->app->config('token_length')))
                ->write;

            $img = Lutim::DB::Image->new(app => $c->app);
        }
    }
}

sub _shortener {
    my $c      = shift;
    my $length = shift;

    my @chars  = ('a'..'z','A'..'Z','0'..'9');
    my $result = '';
    foreach (1..$length) {
        $result .= $chars[entropy_source->get_int(scalar(@chars))];
    }
    return $result;
}

sub _stop_upload {
    my $c = shift;

    if (-f 'stop-upload' || -f 'stop-upload.manual') {
        $c->stash(
            stop_upload => $c->l('Uploading is currently disabled, please try later or contact the administrator (%1).', $c->app->config('contact'))
        );
        return 1;
    }
    return 0;
}

sub _max_delay {
    my $c = shift;

    return $c->app->config('max_delay') if ($c->app->config('max_delay') >= 0);

    warn "max_delay set to a negative value. Default to 0.";
    return 0;
}

sub _default_delay {
    my $c = shift;

    return $c->app->config('default_delay') if ($c->app->config('default_delay') >= 0);

    warn "default_delay set to a negative value. Default to 0.";
    return 0;
}

sub _is_selected {
    my $c   = shift;
    my $num = shift;

    return ($num == $c->default_delay) ? 'selected="selected"' : '';
}

sub _is_wm_selected {
    my $c  = shift;
    my $wm = shift;

    return ($wm eq $c->config('watermark_default')) ? 'selected="selected"' : '';
}

sub _crypt {
    my $c        = shift;
    my $upload   = shift;
    my $filename = shift;

    my $key   = $c->shortener($c->config('crypto_key_length'));
    my $iv    = $c->shortener(8);

    my $cipher = Crypt::CBC->new(
        -key    => $key,
        -cipher => 'Blowfish',
        -header => 'none',
        -iv     => $iv
    );

    $cipher->start('encrypting');

    my $crypt_asset = Mojo::Asset::File->new;

    $crypt_asset->add_chunk($cipher->crypt($upload->slurp));
    $crypt_asset->add_chunk($cipher->finish);

    my $crypt_upload = Mojo::Upload->new;
    $crypt_upload->filename($filename);
    $crypt_upload->asset($crypt_asset);

    return ($crypt_upload, $key, $iv);
}

sub _decrypt {
    my $c    = shift;
    my $key  = shift;
    my $file = shift;
    my $iv   = shift;
    $iv = 'dupajasi' unless $iv;

    my $cipher = Crypt::CBC->new(
        -key    => $key,
        -cipher => 'Blowfish',
        -header => 'none',
        -iv     => $iv
    );

    $cipher->start('decrypting');

    my $decrypt_asset = Mojo::Asset::File->new;

    open(my $f, "<",$file) or die "Unable to read encrypted file: $!";
    binmode $f;
    while (read($f, my $buffer, 1024)) {
          $decrypt_asset->add_chunk($cipher->crypt($buffer));
    }
    $decrypt_asset->add_chunk($cipher->finish) ;

    return $decrypt_asset->slurp;
}

sub _delete_image {
    my $c   = shift;
    my $img = shift;
    if ($c->config('cache_max_size') != 0 || scalar(@{$c->config('memcached_servers')})) {
        $c->chi('lutim_images_cache')->remove($img->short);
    }
    unlink $img->path or warn "Could not unlink ".$img->path.": $!";
    $img->disable();
}

sub _iso639_native_name {
    my $c = shift;
    return ucfirst(decode 'UTF-8', get_iso639_1(shift)->{nativeName});
}

sub _prefix {
    my $c = shift;

    my $prefix = $c->url_for('/')->to_abs;
    # Forced domain
    $prefix->host($c->config('fixed_domain')) if (defined($c->config('fixed_domain')) && $c->config('fixed_domain') ne '');
    # Hack for prefix (subdir) handling
    $prefix .= '/' unless ($prefix =~ m#/$#);
    return $prefix;
}

1;
