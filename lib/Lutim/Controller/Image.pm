# vim:set sw=4 ts=4 sts=4 expandtab:
package Lutim::Controller::Image;
use Mojo::Asset::Memory;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::File qw(path);
use Mojo::Util qw(url_escape url_unescape b64_encode encode);
use Mojo::JSON qw(true false);
use Lutim::DB::Image;
use DateTime;
use Digest::file qw(digest_file_hex);
use Text::Unidecode;
use Data::Validate::URI qw(is_http_uri is_https_uri);
use File::MimeInfo::Magic qw(mimetype extensions);
use IO::Scalar;
use Image::ExifTool;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
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

sub home {
    my $c = shift;

    $c->render(
        template      => 'index',
        max_file_size => $c->req->max_message_size
    );


    $c->on(finish => sub {
            my $c = shift;
            $c->app->log->info('[HIT] someone visited site index') unless $c->config('quiet_logs');
        }
    );
}

sub about {
    shift->render(template => 'about');
}

sub change_lang {
    my $c = shift;
    my $l = $c->param('l');

    $c->cookie(lutim_lang => $l, { path => $c->config('prefix') });

    if ($c->req->headers->referrer) {
        return $c->redirect_to($c->req->headers->referrer);
    } else {
        return $c->redirect_to('/');
    }
}

sub stats {
    my $c = shift;

    my $img = Lutim::DB::Image->new(app => $c);
    $c->render(
        template => 'stats',
        total    =>  $img->count_not_empty
    );
}

sub infos {
    my $c = shift;

    $c->render(
        json => {
            broadcast_message => $c->config('broadcast_message'),
            image_magick      => ($im_loaded) ? true : false,
            contact           => $c->config('contact'),
            max_file_size     => $c->config('max_file_size'),
            default_delay     => $c->config('default_delay'),
            max_delay         => $c->config('max_delay'),
            always_encrypt    => ($c->config('always_encrypt')) ? true : false,
            upload_enabled    => ($c->app->stop_upload()) ? false : true,
        }
    );
}

sub about_img {
    my $c     = shift;
    my $short = $c->param('short');

    my $image = Lutim::DB::Image->new(app => $c->app, short => $short);
    if ($image->enabled && $image->path) {
        return $c->render(
            json => {
                success => true,
                data    => {
                    width  => $image->width,
                    height => $image->height,
                }
            }
        );
    } else {
        return $c->render(
            json => {
                success => false,
                msg     => $c->l('Unable to find the image %1.', $short)
            }
        );
    }
}

sub webapp {
    my $c = shift;

    my $headers = Mojo::Headers->new();
    $headers->add('Content-Type' => 'application/x-web-app-manifest+json');
    $c->res->content->headers($headers);

    $c->render(
        template => 'manifest',
        format   => 'webapp'
    );
}

sub get_counter {
    my $c     = shift;
    my $short = $c->param('short');
    my $token = $c->param('token');

    my $img = Lutim::DB::Image->new(app => $c->app, short => $short);
    if (defined($img->mod_token) && $img->mod_token eq $token) {
        return $c->render(
            json => {
                success => true,
                counter => $img->counter,
                enabled => ($img->enabled) ? true : false
            }
        );
    }
    $c->render(
        json => {
            success => false,
            msg     => $c->l('Unable to get counter')
        }
    );
}

sub modify {
    my $c     = shift;
    my $short = $c->param('short');
    my $token = $c->param('token');
    my $url   = $c->param('url');

    my $image = Lutim::DB::Image->new(app => $c->app, short => $short);
    if ($image->path) {
        my $msg;
        if ($image->mod_token ne $token || $token eq '') {
            $msg = $c->l('The delete token is invalid.');
        } else {
            $c->app->log->info('[MODIFICATION] someone modify '.$image->filename.' with token method (path: '.$image->path.')') unless $c->config('quiet_logs');

            $image->delete_at_day(($c->param('delete-day') && ($c->param('delete-day') <= $c->max_delay || $c->max_delay == 0)) ? $c->param('delete-day') : $c->max_delay);
            $image->delete_at_first_view(($c->param('first-view')) ? 1 : 0);
            $image->write;

            $msg = $c->l('The image’s delay has been successfully modified');
            if (defined($c->param('format')) && $c->param('format') eq 'json') {
                return $c->render(
                    json => {
                        success => Mojo::JSON->true,
                        msg     => $msg
                    }
                );
            } else {
                $msg .= ' (<a href="'.$url.'">'.$url.'</a>)' unless (!defined($url));
                $c->flash(
                    success => $msg
                );
                return $c->redirect_to('/');
            }
        }

        if (defined($c->param('format')) && $c->param('format') eq 'json') {
            return $c->render(
                json => {
                    success => Mojo::JSON->false,
                    msg     => $msg
                }
            );
        } else {
            $c->flash(
                msg => $msg
            );
            return $c->redirect_to('/');
        }
    } else {
        $c->app->log->info('[UNSUCCESSFUL] someone tried to modify '.$short.' but it doesn’t exist.') unless $c->config('quiet_logs');

        # Image never existed
        my $msg = $c->l('Unable to find the image %1.', $short);
        if (defined($c->param('format')) && $c->param('format') eq 'json') {
            return $c->render(
                json => {
                    success => Mojo::JSON->false,
                    msg     => $msg
                }
            );
        } else {
            $c->flash(
                msg => $msg
            );
            return $c->redirect_to('/');
        }
    }
}

sub delete {
    my $c     = shift;
    my $short = $c->param('short');
    my $token = $c->param('token');

    my $image = Lutim::DB::Image->new(app => $c->app, short => $short);
    if ($image->path) {
        my $msg;
        if ($image->mod_token ne $token || $token eq '') {
            $msg = $c->l('The delete token is invalid.');
        } elsif ($image->enabled() == 0) {
            $msg = $c->l('The image %1 has already been deleted.', $image->filename);
        } else {
            $c->app->log->info('[DELETION] someone made '.$image->filename.' removed with token method (path: '.$image->path.')') unless $c->config('quiet_logs');

            $c->delete_image($image);
            return $c->respond_to(
                json => {
                    json => {
                        success => true,
                        msg     => $c->l('The image %1 has been successfully deleted', $image->filename)
                    }
                },
                any => sub {
                    $c->flash(
                        success => $c->l('The image %1 has been successfully deleted', $image->filename)
                    );
                    return $c->redirect_to('/');
                }
            );
        }

        return $c->respond_to(
            json => {
                json => {
                    success => false,
                    msg     => $msg
                }
            },
            any => sub {
                $c->flash(
                    msg => $msg
                );
                return $c->redirect_to('/');
            }
        );
    } else {
        $c->app->log->info('[UNSUCCESSFUL] someone tried to delete '.$short.' but it doesn’t exist.') unless $c->config('quiet_logs');

        # Image never existed
        return $c->respond_to(
            json => {
                json => {
                    success => false,
                    msg     => $c->l('Unable to find the image %1.', $short)
                }
            },
            any => sub {
                $c->helpers->reply->not_found;
            }
        );
    }
}

sub add {
    my $c         = shift;
    my $upload    = $c->param('file');
    my $file_url  = $c->param('lutim-file-url');
    my $keep_exif = $c->param('keep-exif');
    my $wm        = $c->param('watermark');

    if ($c->config('disable_api')) {
        my $unauthorized_api = (!defined($c->req->headers->referrer) || Mojo::URL->new($c->req->headers->referrer)->host ne Mojo::URL->new('https://'.$c->req->headers->host)->host);
        if ($unauthorized_api) {
            my $msg = $c->l('Sorry, the API is disabled');
            $c->app->log->info('Blocked API call for '.$c->ip(1));
            return $c->respond_to(
                json => { json => { success => Mojo::JSON->false, msg => $msg } },
                any  => sub {
                    shift->render(
                        template => 'index',
                        msg      => $msg,
                    );
                }
            );
        }
    }
    if(!defined($c->stash('stop_upload'))) {
        if (defined($file_url) && $file_url) {
            if (is_http_uri($file_url) || is_https_uri($file_url)) {
                # Anti-flood protection
                my $ip = $c->ip(1);
                while (defined($c->app->{wait_for_it}->{$ip}) && (time - $c->app->{wait_for_it}->{$ip}) <= $c->config->{anti_flood_delay} ) {
                    sleep($c->config->{anti_flood_delay});
                }
                my $ua = Mojo::UserAgent->new;
                my $res = $ua->get($file_url => {DNT => 1})->result;
                if ($res->is_success) {
                    $file_url    = url_unescape $file_url;
                    $file_url    =~ m#^.*/([^/?]*)\??.*$#;
                    my $filename = $1;
                    $filename    = 'uploaded.image' unless (defined($filename));
                    $filename   .= '.image' if (index($filename, '.') == -1);
                    $upload      = Mojo::Upload->new(
                        asset    => $res->content->asset,
                        filename => $filename
                    );
                    $c->app->{wait_for_it}->{$ip} = time;
                } elsif ($res->is_limit_exceeded) {
                    my $msg = $c->l('The file exceed the size limit (%1)', $res->max_message_size);
                    if (defined($c->param('format')) && $c->param('format') eq 'json') {
                        return $c->render(
                            json => {
                                success => Mojo::JSON->false,
                                msg     => {
                                    filename => $file_url,
                                    msg      => $msg
                                }
                            }
                        );
                    } else {
                        $c->flash(msg      => $msg);
                        $c->flash(filename => $upload->filename);
                        return $c->redirect_to('/');
                    }
                } else {
                    my $msg = $c->l('An error occured while downloading the image.');
                    $c->app->log->warn('[DOWNLOAD ERROR]'.$c->dumper($res->message));
                    if (defined($c->param('format')) && $c->param('format') eq 'json') {
                        return $c->render(
                            json => {
                                success => Mojo::JSON->false,
                                msg     => {
                                    filename => $file_url,
                                    msg      => $msg
                                }
                            }
                        );
                    } else {
                        $c->flash(msg      => $msg);
                        $c->flash(filename => $file_url);
                        return $c->redirect_to('/');
                    }
                }
            } else {
                my $msg = $c->l('The URL is not valid.');
                if (defined($c->param('format')) && $c->param('format') eq 'json') {
                    return $c->render(
                        json => {
                            success => Mojo::JSON->false,
                            msg     => {
                                filename => $file_url,
                                msg      => $msg
                            }
                        }
                    );
                } else {
                    $c->flash(msg      => $msg);
                    $c->flash(filename => $file_url);
                    return $c->redirect_to('/');
                }
            }
        }

        my $io_scalar = new IO::Scalar \$upload->slurp();
        my $mediatype = mimetype($io_scalar);

        my ($ext) = ($upload->filename =~ m/.*\.(.*)$/);

        my $ip = $c->ip;

        my ($msg, $short, $real_short, $token, $thumb, $limit, $created);
        # Check file type
        if (index($mediatype, 'image/') >= 0) {
            if ($c->req->is_limit_exceeded) {
                $msg = $c->l('The file exceed the size limit (%1)', $c->req->max_message_size);
                if (defined($c->param('format')) && $c->param('format') eq 'json') {
                    return $c->render(
                        json => {
                            success => Mojo::JSON->false,
                            msg     => $msg
                        }
                    );
                } else {
                    $c->flash(msg      => $msg);
                    $c->flash(filename => $upload->filename);
                    return $c->redirect_to('/');
                }
            }
            my $record  = Lutim::DB::Image->new(app => $c->app)->select_empty;
            if ($record->short) {
                # Save file and create record
                my $filename = unidecode($upload->filename);
                my $ext      = ($filename =~ m/([^.]+)$/)[0];
                my $path     = path($c->config('upload_dir'), $record->short.'.'.$ext)->to_string;

                my ($width, $height);
                if ($im_loaded && $mediatype ne 'image/svg+xml' # ImageMagick doesn't work with SVG, xcf or avif files
                               && $mediatype !~ m#image/(x-)?xcf#
                               && $mediatype ne 'image/avif') {
                    my $im  = Image::Magick->new;
                    $im->BlobToImage($upload->slurp);

                    # Automatic rotation from EXIF tag
                    $im->AutoOrient();

                    # Get dimensions
                    $width  = $im->Get('width');
                    $height = $im->Get('height');

                    # Optionally add watermark
                    if ($c->config('watermark_path') && (
                            ($wm && $wm ne 'none') ||
                            $c->config('watermark_enforce') ne 'none'
                        )) {
                        my $watermarkim = Image::Magick->new;
                        $watermarkim->ReadImage($c->config('watermark_path'));
                        $watermarkim->Evaluate(
                            operator => 'Multiply',
                            value    => 0.25,
                            channel  => 'Alpha'
                        );
                        if ($height <= 80) {
                            $watermarkim->Resize(geometry => 'x10');
                        } else {
                            $watermarkim->Resize(geometry => 'x80');
                        }

                        # Add one watermark or repeat it all over the image?
                        my $tilingw = 1 if ($c->config('watermark_enforce') eq 'tiling' || $wm eq 'tiling');
                        my $singlew = 1 if ($c->config('watermark_enforce') eq 'single' || $wm eq 'single');
                        if ($tilingw) {
                            $im->Composite(
                                image   => $watermarkim,
                                compose => 'Dissolve',
                                tile    => 'True',
                                gravity => 'Center'
                            );
                        } elsif ($singlew) {
                            $im->Composite(
                                image   => $watermarkim,
                                compose => 'Dissolve',
                                tile    => 'False',
                                x       => '20',
                                y       => '20',
                                gravity => $c->config('watermark_placement')
                            );
                        }
                    }

                    # Update the uploaded file with it's auto-rotated/watermarked clone
                    my $asset = Mojo::Asset::Memory->new->add_chunk($im->ImageToBlob());
                    $upload->asset($asset);

                    # Create the thumbnail
                    $im->Resize(geometry => 'x85');

                    $thumb  = 'data:'.$mediatype.';base64,';
                    if ($mediatype eq 'image/gif') {
                        $thumb .= b64_encode $im->[0]->ImageToBlob();
                    } else {
                        $thumb .= b64_encode $im->ImageToBlob();
                    }

                }

                unless (defined($keep_exif) && $keep_exif) {
                    # Exiftool can’t process SVG or xcf files
                    if ($mediatype ne 'image/svg+xml'
                        && $mediatype !~ m#image/(x-)?xcf#) {
                        # Remove the EXIF tags
                        my $data = new IO::Scalar \$upload->slurp();
                        my $et   = Image::ExifTool->new;

                        # Remove all metadata
                        $et->SetNewValue('*');

                        # Create a temporary IO::Scalar to write into
                        my $temp;
                        my $a = new IO::Scalar \$temp;
                        $et->WriteInfo($data, $a);

                        # Update the uploaded file with it's no-tags clone
                        $data = Mojo::Asset::Memory->new->add_chunk($temp);
                        $upload->asset($data);
                    }
                }

                my ($key, $iv);
                if ($c->param('crypt') || $c->config('always_encrypt')) {
                    ($upload, $key, $iv) = $c->crypt($upload, $filename);
                }
                $upload->move_to($path);

                $record->path($path)
                       ->filename($filename)
                       ->mediatype($mediatype)
                       ->footprint(digest_file_hex($path, 'SHA-512'))
                       ->enabled(1)
                       ->delete_at_day(($c->param('delete-day') && ($c->param('delete-day') <= $c->max_delay || $c->max_delay == 0)) ? $c->param('delete-day') : $c->max_delay)
                       ->delete_at_first_view(($c->param('first-view'))? 1 : 0)
                       ->created_at(time())
                       ->created_by($ip)
                       ->width($width)
                       ->height($height)
                       ->iv($iv)
                       ->write;

                # Log image creation
                $c->app->log->info('[CREATION] '.$ip.' pushed '.$filename.' (path: '.$path.')') unless $c->config('quiet_logs');

                # Give url to user
                $short      = $record->short;
                $real_short = $short;
                if (!defined($record->mod_token)) {
                    $record->mod_token($c->shortener($c->config->{token_length}))->write;
                }
                $token      = $record->mod_token;
                $short     .= '/'.$key if (defined($key));

                $limit   = $record->delete_at_day;
                $created = $record->created_at;
            } else {
                # Houston, we have a problem
                $msg = $c->l('There is no more available URL. Retry or contact the administrator. %1', $c->config->{contact});
            }
        } else {
            $msg = $c->l('The file %1 is not an image.', $upload->filename);
        }

        if (defined($c->param('format')) && $c->param('format') eq 'json') {
            if (defined($short)) {
                $msg = {
                    filename    => $upload->filename,
                    short       => $short,
                    real_short  => $real_short,
                    token       => $token,
                    ext         => $ext || extensions($mediatype),
                    thumb       => $thumb,
                    del_at_view => ($c->param('first-view')) ? true : false,
                    limit       => $limit,
                    created_at  => $created
                };
            } else {
                $msg = {
                    filename => $upload->filename,
                    msg      => $msg
                };
            }
            return $c->render(
                json => {
                    success => (defined($short)) ? Mojo::JSON->true : Mojo::JSON->false,
                    msg     => $msg
                }
            );
        } else {
            if ((defined($msg))) {
                $c->flash(msg      => $msg);
                $c->flash(filename => $upload->filename);
                return $c->redirect_to('/');
            } else {
                $c->stash(short      => $short) if (defined($short));
                $c->stash(real_short => $real_short);
                $c->stash(token      => $token);
                $c->stash(ext        => $ext || extensions($mediatype));
                $c->stash(thumb      => $thumb);
                $c->stash(filename   => $upload->filename);
                return $c->render(
                    template      => 'index',
                    max_file_size => $c->req->max_message_size
                );
            }
        }
    } else {
        if (defined($c->param('format')) && $c->param('format') eq 'json') {
            return $c->render(
                json => {
                    success => Mojo::JSON->false,
                    msg     => {
                        filename => $upload->filename,
                        msg      => $c->stash('stop_upload')
                    }
                }
            );
        } else {
            $c->flash(msg      => $c->stash('stop_upload'));
            $c->flash(filename => $upload->filename);
            return $c->redirect_to('/');
        }
    }
}

sub short {
    my $c     = shift;
    my $short = $c->param('short');
    my $touit = $c->param('t');
    my $key   = $c->param('key');
    my $thumb;
       $thumb = '' if defined $c->param('thumb');
       $thumb = $c->param('width') if defined $c->param('width');
    my $dl    = (defined($c->param('dl'))) ? 'attachment' : 'inline';

    my $image = Lutim::DB::Image->new(app => $c->app, short => $short);
    if ($image->enabled && $image->path) {
        if($image->delete_at_day && $image->created_at + $image->delete_at_day * 86400 <= time()) {
            # Log deletion
            $c->app->log->info('[DELETION] someone tried to view '.$image->filename.' but it has been removed by expiration (path: '.$image->path.')') unless $c->config('quiet_logs');

            # Delete image
            $c->delete_image($image);

            # Warn user
            $c->flash(
                msg => $c->l('Unable to find the image: it has been deleted.')
            );
            return $c->redirect_to('/');
        }

        my $test;
        if (defined($touit) && $image->mediatype !~ m/svg/) {
            $test = 1;
            my $short  = $image->short;
               $short .= '/'.$key if (defined($key));
            my ($width, $height) = (340,340);
            if ($image->mediatype eq 'image/gif') {
                if (defined($image->width) && defined($image->height)) {
                    ($width, $height) = ($image->width, $image->height);
                } elsif ($im_loaded && $image->mediatype !~ m/xcf|avif/) {
                    my $upload = $c->decrypt($key, $image->path, $image->iv);
                    my $im     = Image::Magick->new;
                    $im->BlobToImage($upload->slurp);
                    $width     = $im->Get('width');
                    $height    = $im->Get('height');

                    $image->width($width)
                          ->height($height)
                          ->write;
                }
            }
            return $c->render(
                template => 'share',
                layout   => undef,
                short    => $short,
                filename => $image->filename,
                mimetype => $image->mediatype,
                width    => $width,
                height   => $height
            );
        } else {
            # Delete image if needed
            if ($image->delete_at_first_view && $image->counter >= 1) {
                # Log deletion
                $c->app->log->info('[DELETION] someone made '.$image->filename.' removed (path: '.$image->path.')') unless $c->config('quiet_logs');

                # Delete image
                $c->delete_image($image);

                $c->flash(
                    msg => $c->l('Unable to find the image: it has been deleted.')
                );
                return $c->redirect_to('/');
            } else {
                $test = $c->render_file($im_loaded, $image, $dl, $key, $thumb);
            }
        }

        if ($test != 500) {
            # Update counter
            $c->on(finish => sub {
                # Log access
                $c->app->log->info('[VIEW] someone viewed '.$image->filename.' (path: '.$image->path.')') unless $c->config('quiet_logs');

                # Update record
                unless ($c->config('disable_img_stats')) {
                    if ($c->config('minion')->{enabled}) {
                        $c->app->minion->enqueue(accessed => [$image->short, time]);
                    } else {
                        $image->accessed(time);
                    }
                }

                # Delete image if needed
                if ($image->delete_at_first_view) {
                    # Log deletion
                    $c->app->log->info('[DELETION] someone made '.$image->filename.' removed (path: '.$image->path.')') unless $c->config('quiet_logs');

                    # Delete image
                    $c->delete_image($image);
                }
            });
        } else {
            $c->app->log->error('[ERROR] Can’t render '.$image->short);
        }
    } elsif ($image->path && !$image->enabled) {
        # Log access try
        $c->app->log->info('[NOT FOUND] someone tried to view '.$short.' but it doesn’t exist anymore.') unless $c->config('quiet_logs');

        # Warn user
        $c->flash(
            msg => $c->l('Unable to find the image: it has been deleted.')
        );
        return $c->redirect_to('/');
    } else {
        # Image never existed
        $c->helpers->reply->not_found;
    }
}

sub zip {
    my $c     = shift;
    my $imgs  = $c->every_param('i');

    my $img_nb  = scalar(@{$imgs});
    my $max_zip = $c->config('max_files_in_zip');

    if ($img_nb <= $max_zip) {
        my $zip = Archive::Zip->new();

        # We HAVE to add a png file at the beginning, otherwise the $zip
        # could use the mimetype of an SVG file if it's the first file asked.
        $zip->addFile('themes/default/public/img/favicon.png', 'hosted_with_lutim.png');

        $zip->addDirectory('images/');
        for my $img (@{$imgs}) {
            my ($short, $key) = split('/', $img);
            if (defined $key) {
                $key =~ s/\.[^.]*//;
            } else {
                $short =~ s/\.[^.]*//;
            }
            my $image = Lutim::DB::Image->new(app => $c->app, short => $short);

            if ($image->enabled && $image->path) {
                my $filename = $image->filename;
                if($image->delete_at_day && $image->created_at + $image->delete_at_day * 86400 <= time()) {
                    # Log deletion
                    $c->app->log->info('[DELETION] someone tried to view '.$image->filename.' but it has been removed by expiration (path: '.$image->path.')') unless $c->config('quiet_logs');

                    # Delete image
                    $c->delete_image($image);

                    # Warn user
                    $zip->addString(encode('UTF-8', $c->l('Unable to find the image: it has been deleted.')), 'images/'.$filename.'.txt');
                    next;
                }

                # Delete image if needed
                if ($image->delete_at_first_view && $image->counter >= 1) {
                    # Log deletion
                    $c->app->log->info('[DELETION] someone made '.$image->filename.' removed (path: '.$image->path.')') unless $c->config('quiet_logs');

                    # Delete image
                    $c->delete_image($image);

                    $zip->addString(encode('UTF-8', $c->l('Unable to find the image: it has been deleted.')), 'images/'.$filename.'.txt');
                    next;
                } else {
                    my $expires = ($image->delete_at_day) ? $image->delete_at_day : 360;
                    my $dt = DateTime->from_epoch( epoch => $expires * 86400 + $image->created_at);
                    $dt->set_time_zone('GMT');
                    $expires = $dt->strftime("%a, %d %b %Y %H:%M:%S GMT");

                    my $path = $image->path;
                    unless ( -f $path && -r $path ) {
                        $c->app->log->error("Cannot read file [$path]. error [$!]");
                        $zip->addString(encode('UTF-8', $c->l('Unable to find the image: it has been deleted.')), 'images/'.$filename.'.txt');
                        next;
                    }

                    if ($key) {
                        $zip->addString($c->decrypt($key, $path, $image->iv), "images/$filename");
                    } else {
                        $zip->addFile($path, "images/$filename");
                    }

                    # Log access
                    $c->app->log->info('[VIEW] someone viewed '.$image->filename.' (path: '.$image->path.')') unless $c->config('quiet_logs');

                    # Update counter and record
                    unless ($c->config('disable_img_stats')) {
                        if ($c->config('minion')->{enabled}) {
                            $c->app->minion->enqueue(accessed => [$image->short, time]);
                        } else {
                            $image->accessed(time);
                        }
                    }
                }
            } elsif ($image->path && !$image->enabled) {
                # Log access try
                $c->app->log->info('[NOT FOUND] someone tried to view '.$short.' but it doesn’t exist anymore.') unless $c->config('quiet_logs');

                # Warn user
                $zip->addString(encode('UTF-8', $c->l('Unable to find the image: it has been deleted.')), 'images/'.$image->filename.'.txt');
                next;
            } else {
                $zip->addString(encode('UTF-8', $c->l('Image not found.')), 'images/'.$short.'.txt');
                next;
            }
        }
        my ($fh, $zipfile) = Archive::Zip::tempFile();
        unless ($zip->writeToFileNamed($zipfile) == AZ_OK) {
            $c->flash(
                msg => $c->l('Something went wrong when creating the zip file. Try again later or contact the administrator (%1).', $c->config('contact'))
            );
            return $c->redirect_to('/');
        }
        $c->res->content->headers->content_type('application/zip;name=images.zip');
        $c->res->content->headers->content_disposition('attachment;filename=images.zip');;

        my $asset = Mojo::Asset::File->new(path => $zipfile);
        $c->res->content->asset($asset);
        $c->res->content->headers->content_length($asset->size);

        unlink $zipfile;

        return $c->rendered(200);
    } else {
        my $i    = -1;
        my @urls = ();
        my @esc_imgs = map { my $e = $_; $e = url_escape($e); $e =~ s#%2F#/#g; $e } @{$imgs};
        while (++$i < $img_nb) {
            my $stop = ($i + $max_zip - 1 < $img_nb) ? $i + $max_zip - 1 : $img_nb - 1;
            push @urls, $c->url_for('/zip')->to_abs->to_string.'?i='.join('&i=', @esc_imgs[$i..$stop]);
            $i = $stop;
        }
        $c->render(
            template => 'zip',
            urls     => \@urls
        );
    }
}

sub random {
    my $c     = shift;
    my $imgs  = $c->every_param('i');

    my $img_nb  = scalar(@{$imgs});
    if ($img_nb) {
        $c->redirect_to($c->prefix.$imgs->[entropy_source->get_int($img_nb)]);
    } else {
        $c->render_not_found;
    }
}

1;
