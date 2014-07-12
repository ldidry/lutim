# vim:set sw=4 ts=4 sts=4 expandtab:
package Lutim::Controller;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw(url_unescape b64_encode);
use DateTime;
use File::Type;
use Digest::file qw(digest_file_hex);
use Text::Unidecode;
use Data::Validate::URI qw(is_http_uri is_https_uri);

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
            $msg = $c->l('invalid_token');
        } else {
            $c->app->log->info('[MODIFICATION] someone modify '.$image->filename.' with token method (path: '.$image->path.')');

            $image->update(
                delete_at_day        => ($c->param('delete-day') && $c->param('delete-day') <= $c->max_delay) ? $c->param('delete-day') : $c->max_delay,
                delete_at_first_view => ($c->param('first-view')) ? 1 : 0,
            );
            $msg = $c->l('image_delay_modified');
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
        my $msg = $c->l('image_mod_not_found', $short);
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
            $msg = $c->l('invalid_token');
        } elsif ($image->enabled() == 0) {
            $msg = $c->l('already_deleted', $image->filename);
        } else {
            $c->app->log->info('[DELETION] someone made '.$image->filename.' removed with token method (path: '.$image->path.')');

            $c->delete_image($image);
            $c->flash(
                success => $c->l('image_deleted', $image->filename)
            );
            return $c->redirect_to('/');
        }

        $c->flash(
            msg => $msg
        );
        return $c->redirect_to('/');
    } else {
        $c->app->log->info('[UNSUCCESSFUL] someone tried to delete '.$short.' but it does\'nt exist.');

        # Image never existed
        $c->render_not_found;
    }
}

sub add {
    my $c        = shift;
    my $upload   = $c->param('file');
    my $file_url = $c->param('lutim-file-url');

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
                    $file_url    =~ m#^.*/([^/]*)$#;
                    my $filename = $1;
                    $filename    = 'uploaded.image' unless (defined($filename));
                    $filename   .= '.image' if (index($filename, '.') == -1);
                    $upload      = Mojo::Upload->new(
                        asset    => $res->content->asset,
                        filename => $filename
                    );
                    $c->app->{wait_for_it}->{$ip} = time;
                } elsif ($tx->res->is_limit_exceeded) {
                    my $msg = $c->l('file_too_big', $tx->res->max_message_size);
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
                    my $msg = $c->l('download_error');
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
                my $msg = $c->l('no_valid_url');
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

        my $ft = File::Type->new();
        my $mediatype = $ft->mime_type($upload->slurp());

        my $ip = $c->ip;

        my ($msg, $short, $real_short, $token, $thumb);
        # Check file type
        if (index($mediatype, 'image/') >= 0) {
            # Create directory if needed
            mkdir('files', 0700) unless (-d 'files');

            if ($c->req->is_limit_exceeded) {
                $msg = $c->l('file_too_big', $c->req->max_message_size);
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
                    if ($im_loaded) {
                        my $im = Image::Magick->new;
                        $im->BlobToImage($upload->slurp);
                        $im->Resize(geometry=>'x85');

                        $thumb  = 'data:'.$mediatype.';base64,';
                        $thumb .= b64_encode $im->ImageToBlob();
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
                        delete_at_day        => ($c->param('delete-day') && $c->param('delete-day') <= $c->max_delay) ? $c->param('delete-day') : $c->max_delay,
                        delete_at_first_view => ($c->param('first-view')) ? 1 : 0,
                        created_at           => time(),
                        created_by           => $ip
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
                } else {
                    # Houston, we have a problem
                    $msg = $c->l('no_more_short', $c->config->{contact});
                }
            }
            LutimModel->commit;
        } else {
            $msg = $c->l('no_valid_file', $upload->filename);
        }

        if (defined($c->param('format')) && $c->param('format') eq 'json') {
            if (defined($short)) {
                $msg = {
                    filename   => $upload->filename,
                    short      => $short,
                    real_short => $real_short,
                    token      => $token,
                    thumb      => $thumb
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
                msg => $c->l('image_not_found')
            );
            return $c->redirect_to('/');
        }

        my $test;
        if (defined($touit)) {
            $test = 1;
            my $short  = $images[0]->short;
               $short .= '/'.$key if (defined($key));
            return $c->render(
                template => 'twitter',
                layout   => undef,
                short    => $short,
                filename => $images[0]->filename
            );
        } else {
            # Delete image if needed
            if ($images[0]->delete_at_first_view && $images[0]->counter >= 1) {
                # Log deletion
                $c->app->log->info('[DELETION] someone made '.$images[0]->filename.' removed (path: '.$images[0]->path.')');

                # Delete image
                $c->delete_image($images[0]);

                $c->flash(
                    msg => $c->l('image_not_found')
                );
                return $c->redirect_to('/');
            } else {
                my $expires = ($images[0]->delete_at_day) ? $images[0]->delete_at_day : 360;
                my $dt = DateTime->from_epoch( epoch => $expires * 86400 + $images[0]->created_at);
                $dt->set_time_zone('GMT');
                $expires = $dt->strftime("%a, %d %b %Y %H:%M:%S GMT");

                $test = $c->render_file($images[0]->filename, $images[0]->path, $images[0]->mediatype, $dl, $expires, $images[0]->delete_at_first_view, $key);
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
                msg => $c->l('image_not_found')
            );
            return $c->redirect_to('/');
        } else {
            # Image never existed
            $c->render_not_found;
        }
    }
}

1;
