# vim:set sw=4 ts=4 sts=4 expandtab:
package Lutim::Controller;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw(url_unescape b64_encode);
use Mojo::Asset::Memory;
use Mojo::JSON qw(true false);
use DateTime;
use Digest::file qw(digest_file_hex);
use Text::Unidecode;
use Data::Validate::URI qw(is_http_uri is_https_uri);
use File::MimeInfo::Magic qw(mimetype extensions);
use IO::Scalar;
use Image::ExifTool;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

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
            $c->app->log->info('[HIT] someone visited site index');
        }
    );
}

sub about {
    shift->render(template => 'about');
}

sub stats {
    shift->render(
        template => 'stats',
        total    =>  LutimModel::Lutim->count('WHERE path IS NOT NULL')
    );
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

    my @images = LutimModel::Lutim->select('WHERE short = ? AND path IS NOT NULL AND mod_token = ?', ($short, $token));
    if (scalar(@images)) {
        return $c->render(
            json => {
                success => true,
                counter => $images[0]->counter,
                enabled => ($images[0]->enabled) ? true : false
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

    my @images = LutimModel::Lutim->select('WHERE short = ? AND path IS NOT NULL', $short);
    if (scalar(@images)) {
        my $image = $images[0];
        my $msg;
        if ($image->mod_token() ne $token || $token eq '') {
            $msg = $c->l('The delete token is invalid.');
        } else {
            $c->app->log->info('[MODIFICATION] someone modify '.$image->filename.' with token method (path: '.$image->path.')');

            $image->update(
                delete_at_day        => ($c->param('delete-day') && ($c->param('delete-day') <= $c->max_delay || $c->max_delay == 0)) ? $c->param('delete-day') : $c->max_delay,
                delete_at_first_view => ($c->param('first-view')) ? 1 : 0,
            );
            $msg = $c->l('The image\'s delay has been successfully modified');
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
        $c->app->log->info('[UNSUCCESSFUL] someone tried to modify '.$short.' but it does\'nt exist.');

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

    my @images = LutimModel::Lutim->select('WHERE short = ? AND path IS NOT NULL', $short);
    if (scalar(@images)) {
        my $image = $images[0];
        my $msg;
        if ($image->mod_token() ne $token || $token eq '') {
            $msg = $c->l('The delete token is invalid.');
        } elsif ($image->enabled() == 0) {
            $msg = $c->l('The image %1 has already been deleted.', $image->filename);
        } else {
            $c->app->log->info('[DELETION] someone made '.$image->filename.' removed with token method (path: '.$image->path.')');

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
        $c->app->log->info('[UNSUCCESSFUL] someone tried to delete '.$short.' but it does\'nt exist.');

        # Image never existed
        return $c->respond_to(
            json => {
                json => {
                    success => false,
                    msg     => $c->l('Unable to find the image %1.', $short)
                }
            },
            any => sub {
                shift->render_not_found;
            }
        );
    }
}

sub add {
    my $c         = shift;
    my $upload    = $c->param('file');
    my $file_url  = $c->param('lutim-file-url');
    my $keep_exif = $c->param('keep-exif');

    if(!defined($c->stash('stop_upload'))) {
        if (defined($file_url) && $file_url) {
            if (is_http_uri($file_url) || is_https_uri($file_url)) {
                # Anti-flood protection
                my $ip = $c->ip(1);
                while (defined($c->app->{wait_for_it}->{$ip}) && (time - $c->app->{wait_for_it}->{$ip}) <= $c->config->{anti_flood_delay} ) {
                    sleep($c->config->{anti_flood_delay});
                }
                my $ua = Mojo::UserAgent->new;
                my $tx = $ua->get($file_url => {DNT => 1});
                if (my $res = $tx->success) {
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
                } elsif ($tx->res->is_limit_exceeded) {
                    my $msg = $c->l('The file exceed the size limit (%1)', $tx->res->max_message_size);
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
                    $c->app->log->warn('[DOWNLOAD ERROR]'.$c->dumper($tx->error));
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
            # Create directory if needed
            mkdir('files', 0700) unless (-d 'files');

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
            if(LutimModel->begin) {
                my @records = LutimModel::Lutim->select('WHERE path IS NULL LIMIT 1');
                if (scalar(@records)) {
                    # Save file and create record
                    my $filename = unidecode($upload->filename);
                    my $ext      = ($filename =~ m/([^.]+)$/)[0];
                    my $path     = 'files/'.$records[0]->short.'.'.$ext;

                    my ($width, $height);
                    if ($im_loaded && $mediatype ne 'image/svg+xml' && $mediatype !~ m#image/(x-)?xcf# && $mediatype ne 'image/webp') { # ImageMagick don't work in Debian with svg (for now?)
                        my $im  = Image::Magick->new;
                        $im->BlobToImage($upload->slurp);

                        # Automatic rotation from EXIF tag
                        $im->AutoOrient();

                        # Update the uploaded file with it's auto-rotated clone
                        my $asset = Mojo::Asset::Memory->new->add_chunk($im->ImageToBlob());
                        $upload->asset($asset);

                        # Create the thumbnail
                        $width  = $im->Get('width');
                        $height = $im->Get('height');
                        $im->Resize(geometry=>'x85');

                        $thumb  = 'data:'.$mediatype.';base64,';
                        if ($mediatype eq 'image/gif') {
                            $thumb .= b64_encode $im->[0]->ImageToBlob();
                        } else {
                            $thumb .= b64_encode $im->ImageToBlob();
                        }

                    }

                    unless ((defined($keep_exif) && $keep_exif) || $mediatype eq 'image/svg+xml' || $mediatype !~ m#image/(x-)?xcf# || $mediatype ne 'image/webp') {
                        # Remove the EXIF tags
                        my $data = new IO::Scalar \$upload->slurp();
                        my $et   = new Image::ExifTool;

                        # Use $data in Image::ExifTool object
                        $et->ExtractInfo($data);
                        # Remove all metadata
                        $et->SetNewValue('*', undef);

                        # Create a temporary IO::Scalar to write into
                        my $temp;
                        my $a = new IO::Scalar \$temp;
                        $et->WriteInfo($data, $a);

                        # Update the uploaded file with it's no-tags clone
                        $data = Mojo::Asset::Memory->new->add_chunk($temp);
                        $upload->asset($data);
                    }

                    my $key;
                    if ($c->param('crypt') || $c->config->{always_encrypt}) {
                        ($upload, $key) = $c->crypt($upload, $filename);
                    }
                    $upload->move_to($path);

                    $records[0]->update(
                        path                 => $path,
                        filename             => $filename,
                        mediatype            => $mediatype,
                        footprint            => digest_file_hex($path, 'SHA-512'),
                        enabled              => 1,
                        delete_at_day        => ($c->param('delete-day') && ($c->param('delete-day') <= $c->max_delay || $c->max_delay == 0)) ? $c->param('delete-day') : $c->max_delay,
                        delete_at_first_view => ($c->param('first-view')) ? 1 : 0,
                        created_at           => time(),
                        created_by           => $ip,
                        width                => $width,
                        height               => $height
                    );

                    # Log image creation
                    $c->app->log->info('[CREATION] '.$ip.' pushed '.$filename.' (path: '.$path.')');

                    # Give url to user
                    $short      = $records[0]->short;
                    $real_short = $short;
                    if (!defined($records[0]->mod_token)) {
                        $records[0]->update(
                            mod_token => $c->shortener($c->config->{token_length})
                        );
                    }
                    $token      = $records[0]->mod_token;
                    $short     .= '/'.$key if (defined($key));

                    $limit   = $records[0]->delete_at_day;
                    $created = $records[0]->created_at;
                } else {
                    # Houston, we have a problem
                    $msg = $c->l('There is no more available URL. Retry or contact the administrator. %1', $c->config->{contact});
                }
            }
            LutimModel->commit;
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
    my $thumb = $c->param('thumb');
    my $dl    = (defined($c->param('dl'))) ? 'attachment' : 'inline';

    my @images = LutimModel::Lutim->select('WHERE short = ? AND ENABLED = 1 AND path IS NOT NULL', $short);

    if (scalar(@images)) {
        if($images[0]->delete_at_day && $images[0]->created_at + $images[0]->delete_at_day * 86400 <= time()) {
            # Log deletion
            $c->app->log->info('[DELETION] someone tried to view '.$images[0]->filename.' but it has been removed by expiration (path: '.$images[0]->path.')');

            # Delete image
            $c->delete_image($images[0]);

            # Warn user
            $c->flash(
                msg => $c->l('Unable to find the image: it has been deleted.')
            );
            return $c->redirect_to('/');
        }

        my $test;
        if (defined($touit)) {
            $test = 1;
            my $short  = $images[0]->short;
               $short .= '/'.$key if (defined($key));
            my ($width, $height) = (340,340);
            if ($images[0]->mediatype eq 'image/gif') {
                if (defined($images[0]->width) && defined($images[0]->height)) {
                    ($width, $height) = ($images[0]->width, $images[0]->height);
                } elsif ($im_loaded) {
                    my $upload = $c->decrypt($key, $images[0]->path);
                    my $im     = Image::Magick->new;
                    $im->BlobToImage($upload->slurp);
                    $width     = $im->Get('width');
                    $height    = $im->Get('height');

                    $images[0]->update(
                        width  => $width,
                        height => $height
                    );
                }
            }
            return $c->render(
                template => 'twitter',
                layout   => undef,
                short    => $short,
                filename => $images[0]->filename,
                mimetype => ($c->req->url->to_abs()->scheme eq 'https') ? $images[0]->mediatype : '',
                width    => $width,
                height   => $height
            );
        } else {
            # Delete image if needed
            if ($images[0]->delete_at_first_view && $images[0]->counter >= 1) {
                # Log deletion
                $c->app->log->info('[DELETION] someone made '.$images[0]->filename.' removed (path: '.$images[0]->path.')');

                # Delete image
                $c->delete_image($images[0]);

                $c->flash(
                    msg => $c->l('Unable to find the image: it has been deleted.')
                );
                return $c->redirect_to('/');
            } else {
                my $expires = ($images[0]->delete_at_day) ? $images[0]->delete_at_day : 360;
                my $dt = DateTime->from_epoch( epoch => $expires * 86400 + $images[0]->created_at);
                $dt->set_time_zone('GMT');
                $expires = $dt->strftime("%a, %d %b %Y %H:%M:%S GMT");

                $test = $c->render_file($images[0]->filename, $images[0]->path, $images[0]->mediatype, $dl, $expires, $images[0]->delete_at_first_view, $key, $thumb);
            }
        }

        if ($test != 500) {
            # Update counter
            $c->on(finish => sub {
                # Log access
                $c->app->log->info('[VIEW] someone viewed '.$images[0]->filename.' (path: '.$images[0]->path.')');

                # Update record
                my $counter = $images[0]->counter + 1;
                $images[0]->update(counter => $counter);

                $images[0]->update(last_access_at => time());

                # Delete image if needed
                if ($images[0]->delete_at_first_view) {
                    # Log deletion
                    $c->app->log->info('[DELETION] someone made '.$images[0]->filename.' removed (path: '.$images[0]->path.')');

                    # Delete image
                    $c->delete_image($images[0]);
                }
            });
        }
    } else {
        @images = LutimModel::Lutim->select('WHERE short = ? AND ENABLED = 0 AND path IS NOT NULL', $short);

        if (scalar(@images)) {
            # Log access try
            $c->app->log->info('[NOT FOUND] someone tried to view '.$short.' but it does\'nt exist anymore.');

            # Warn user
            $c->flash(
                msg => $c->l('Unable to find the image: it has been deleted.')
            );
            return $c->redirect_to('/');
        } else {
            # Image never existed
            $c->render_not_found;
        }
    }
}

sub zip {
    my $c     = shift;
    my $imgs  = $c->every_param('i');

    my $zip = Archive::Zip->new();

    # We HAVE to add a png file at the beginning, otherwise the $zip
    # could use the mimetype of an SVG file if it's the first file asked.
    $zip->addFile('public/img/favicon.png', 'hosted_with_lutim.png');

    $zip->addDirectory('images/');
    for my $img (@{$imgs}) {
        my ($short, $key) = split('/', $img);
        if (defined $key) {
            $key =~ s/\.[^.]*//;
        } else {
            $short =~ s/\.[^.]*//;
        }
        my @images = LutimModel::Lutim->select('WHERE short = ? AND ENABLED = 1 AND path IS NOT NULL', $short);

        if (scalar(@images)) {
            my $filename = $images[0]->filename;
            if($images[0]->delete_at_day && $images[0]->created_at + $images[0]->delete_at_day * 86400 <= time()) {
                # Log deletion
                $c->app->log->info('[DELETION] someone tried to view '.$images[0]->filename.' but it has been removed by expiration (path: '.$images[0]->path.')');

                # Delete image
                $c->delete_image($images[0]);

                # Warn user
                $zip->addString($c->l('Unable to find the image: it has been deleted.'), 'images/'.$filename.'.txt');
                next;
            }

            # Delete image if needed
            if ($images[0]->delete_at_first_view && $images[0]->counter >= 1) {
                # Log deletion
                $c->app->log->info('[DELETION] someone made '.$images[0]->filename.' removed (path: '.$images[0]->path.')');

                # Delete image
                $c->delete_image($images[0]);

                $zip->addString($c->l('Unable to find the image: it has been deleted.'), 'images/'.$filename.'.txt');
                next;
            } else {
                my $expires = ($images[0]->delete_at_day) ? $images[0]->delete_at_day : 360;
                my $dt = DateTime->from_epoch( epoch => $expires * 86400 + $images[0]->created_at);
                $dt->set_time_zone('GMT');
                $expires = $dt->strftime("%a, %d %b %Y %H:%M:%S GMT");

                my $path = $images[0]->path;
                unless ( -f $path && -r $path ) {
                    $c->app->log->error("Cannot read file [$path]. error [$!]");
                    $zip->addString($c->l('Unable to find the image: it has been deleted.'), 'images/'.$filename.'.txt');
                    next;
                }

                if ($key) {
                    $zip->addString($c->decrypt($key, $path)->slurp, "images/$filename");
                } else {
                    $zip->addFile($path, "images/$filename");
                }

                # Log access
                $c->app->log->info('[VIEW] someone viewed '.$images[0]->filename.' (path: '.$images[0]->path.')');
                # Update counter
                $images[0]->update(counter => $images[0]->counter + 1);
                # Update record
                $images[0]->update(last_access_at => time());
            }
        } else {
            @images = LutimModel::Lutim->select('WHERE short = ? AND ENABLED = 0 AND path IS NOT NULL', $short);

            if (scalar(@images)) {
                # Log access try
                $c->app->log->info('[NOT FOUND] someone tried to view '.$short.' but it does\'nt exist anymore.');

                # Warn user
                $zip->addString($c->l('Unable to find the image: it has been deleted.'), 'images/'.$images[0]->filename.'.txt');
                next;
            } else {
                $zip->addString($c->l('Image not found.'), 'images/'.$short.'.txt');
                next;
            }
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
}

1;
