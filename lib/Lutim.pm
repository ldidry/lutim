package Lutim;
use Mojo::Base 'Mojolicious';
use LutimModel;
use File::Type;
use Mojo::Util qw(quote);
use Mojo::JSON;;
use Digest::file qw(digest_file_hex);
use Text::Unidecode;

$ENV{MOJO_TMPDIR} = 'tmp';
mkdir($ENV{MOJO_TMPDIR}, 0700) unless (-d $ENV{MOJO_TMPDIR});
# This method will run once at server start
sub startup {
    my $self = shift;

    $self->plugin('I18N');

    my $config = $self->plugin('Config');

    # Default values
    $config->{provisioning}  = 100 unless (defined($config->{provisionning}));
    $config->{provisioning}  = 100 unless (defined($config->{provisioning}));
    $config->{provis_step}   = 5   unless (defined($config->{provis_step}));
    $config->{length}        = 8   unless (defined($config->{length}));

    die "You need to provide a contact information in lutim.conf !" unless (defined($config->{contact}));

    $ENV{MOJO_MAX_MESSAGE_SIZE} = $config->{max_file_size} if (defined($config->{max_file_size}));

    $self->secrets($config->{secrets});

    $self->helper(
        render_file => sub {
            my $c = shift;
            my ($filename, $path, $mediatype, $dl) = @_;

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

            $asset      = Mojo::Asset::File->new(path => $path);
            my $headers = Mojo::Headers->new();
            $headers->add('Content-Type'        => $mediatype.';name='.$filename);
            $headers->add('Content-Disposition' => $dl.';filename='.$filename);
            $headers->add('Content-Length'      => $asset->size);
            $c->res->content->headers($headers);
            $c->res->content->asset($asset);
            return $c->rendered(200);
        }
    );

    $self->helper(
        ip => sub {
            my $c  = shift;

            my $proxy = '';
            my @x_forward = $c->req->headers->header('X-Forwarded-For');
            for my $x (@x_forward) {
                $proxy .= join(', ', @$x);
            }
            return ($proxy) ? $proxy : $c->tx->remote_address;
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
                        } while (LutimModel::Lutim->count('WHERE short = ?', $short) || $short eq 'about' || $short eq 'stats');

                        LutimModel::Lutim->create(
                            short                => $short,
                            counter              => 0,
                            enabled              => 1,
                            delete_at_first_view => 0,
                            delete_at_day        => 0
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

    $self->hook(
        before_dispatch => sub {
            my $c = shift;
            $c->stop_upload();
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
        }
    );

    $self->hook(
        after_dispatch => sub {
            shift->provisioning();
        }
    );


    $self->defaults(layout => 'default');

    $self->provisioning();

    # Router
    my $r = $self->routes;

    $r->options(sub {
        my $c = shift;
        $c->res->headers->allow('POST');
        $c->render(data => '', status => 204);
    });

    $r->get('/' => sub {
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
    )->name('index');

    $r->get('/about' => sub {
            shift->render(template => 'about');
        }
    )->name('about');

    $r->get('/stats' => sub {
            my $c = shift;

            $c->render(
                template => 'stats',
                total    =>  LutimModel::Lutim->count('WHERE path IS NOT NULL')
            );
        }
    )->name('stats');

    $r->post('/' => sub {
            my $c      = shift;
            my $upload = $c->param('file');

            if(!defined($c->stash('stop_upload'))) {
                my $ft = File::Type->new();
                my $mediatype = $ft->mime_type($upload->slurp());

                my $ip = $c->ip;

                my ($msg, $short);
                # Check file type
                if (index($mediatype, 'image/') >= 0) {
                    # Create directory if needed
                    mkdir('files', 0700) unless (-d 'files');

                    if ($c->req->is_limit_exceeded) {
                        $msg = l('file_too_big', $c->req->max_message_size);
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
                            $upload->move_to($path);
                            $records[0]->update(
                                path                 => $path,
                                filename             => $filename,
                                mediatype            => $mediatype,
                                footprint            => digest_file_hex($path, 'SHA-512'),
                                enabled              => 1,
                                delete_at_day        => ($c->param('delete-day')) ? $c->param('delete-day') : 0,
                                delete_at_first_view => ($c->param('first-view')) ? 1 : 0,
                                created_at           => time(),
                                created_by           => $ip
                            );

                            # Log image creation
                            $c->app->log->info('[CREATION] '.$c->ip.' pushed '.$filename.' (path: '.$path.')');

                            # Give url to user
                            $short = $records[0]->short;
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
                            filename => $upload->filename,
                            short    => $short
                        };
                    } else {
                        $msg = {
                            filename => $upload->filename,
                            msg      => $msg
                        };
                    }
                    $c->render(
                        json => {
                            success => (defined($short)) ? Mojo::JSON->true : Mojo::JSON->false,
                            msg     => $msg
                        }
                    );
                } else {
                    $c->flash(msg      => $msg)   if (defined($msg));
                    $c->flash(short    => $short) if (defined($short));
                    $c->flash(filename => $upload->filename);
                    $c->redirect_to('/');
                }
            } else {
                if (defined($c->param('format')) && $c->param('format') eq 'json') {
                    $c->render(
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
                    $c->redirect_to('/');
                }
            }
        }
    )->name('add');

    $r->get('/:short' => sub {
        my $c     = shift;
        my $short = $c->param('short');
        my $touit = $c->param('t');
        my $dl    = (defined($c->param('dl'))) ? 'attachment' : 'inline';

        my @images = LutimModel::Lutim->select('WHERE short = ? AND ENABLED = 1 AND path IS NOT NULL', $short);

        if (scalar(@images)) {
            if($images[0]->delete_at_day && $images[0]->created_at + $images[0]->delete_at_day * 86400 <= time()) {
                # Log deletion
                $c->app->log->info('[DELETION] someone tried to view '.$images[0]->filename.' but it has been removed by expiration (path: '.$images[0]->path.')');

                # Delete image
                unlink $images[0]->path();
                $images[0]->update(enabled => 0);

                # Warn user
                $c->flash(
                    msg => $c->l('image_not_found')
                );
                return $c->redirect_to('/');
            }

            my $test;
            if (defined($touit)) {
                $test = 1;
                $c->render(
                    template => 'twitter',
                    layout   => undef,
                    short    => $images[0]->short,
                    filename => $images[0]->filename
                );
            } else {
                $test = $c->render_file($images[0]->filename, $images[0]->path, $images[0]->mediatype, $dl);
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
                        unlink $images[0]->path();
                        $images[0]->update(enabled => 0);
                    }
                });
            }
        } else {
            @images = LutimModel::Lutim->select('WHERE short = ? AND ENABLED = 0 AND path IS NOT NULL', $short);

            if (scalar(@images)) {
                # Log access try
                $c->app->log->info('[NOT FOUND] someone tried to view '.$short.' but it does\'nt exist.');

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
    })->name('short');
}

1;
