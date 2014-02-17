package Lutim;
use Mojo::Base 'Mojolicious';
use LutimModel;
use MIME::Types 'by_suffix';
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
    $config->{provisionning} = 100 unless (defined($config->{provisionning}));
    $config->{provis_step}   = 5   unless (defined($config->{provis_step}));
    $config->{length}        = 8   unless (defined($config->{length}));

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
            my @ip = ($c->tx->remote_address eq '127.0.0.1' && $c->app->mode eq 'production') ? $c->tx->req->{content}->{headers}->{headers}->{'x-forwarded-for'}->[0]->[0] : ($c->tx->remote_address);
            return join(',', @ip);
        }
    );

    $self->helper(
        provisionning => sub {
            my $c = shift;

            # Create some short patterns for provisionning
            if (LutimModel::Lutim->count('WHERE path IS NULL') < $c->config->{provisionning}) {
                for (my $i = 0; $i < $c->config->{provis_step}; $i++) {
                    if (LutimModel->begin) {
                        my $short;
                        do {
                            $short= $c->shortener($c->config->{length});
                        } while (LutimModel::Lutim->count('WHERE short = ?', $short));

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

    $self->defaults(layout => 'default');

    $self->provisionning();

    # Router
    my $r = $self->routes;

    $r->get('/' => sub {
            my $c = shift;

            $c->render(
                template      => 'index',
                max_file_size => $c->req->max_message_size
            );

            # Check provisionning
            $c->on(finish => sub {
                    my $c = shift;
                    $c->provisionning();
                    $c->app->log->info('[HIT] '.$c->ip.' visited site index');
                }
            );
        }
    )->name('index');

    $r->post('/' => sub {
            my $c      = shift;
            my $upload = $c->param('file');

            my ($mediatype, $encoding) = by_suffix $upload->filename;

            my $ip = $c->ip;

            my ($msg, $short);
            # Check file type
            if (index($mediatype, 'image') >= 0) {
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
                        $c->app->log->info('[CREATION] '.$ip.' pushed '.$filename.' (path: '.$path.')');

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

            # Check provisionning
            $c->on(finish => sub {
                    shift->provisionning();
                }
            );

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
        }
    )->name('add');

    $r->get('/:short' => sub {
        my $c     = shift;
        my $short = $c->param('short');
        my $touit = $c->param('t');
        my $dl    = (defined($c->param('dl'))) ? 'attachment' : 'inline';

        my @images = LutimModel::Lutim->select('WHERE short = ? AND ENABLED = 1 AND path IS NOT NULL', $short);
        my $ip     = $c->ip;

        if (scalar(@images)) {
            if($images[0]->delete_at_day && $images[0]->created_at + $images[0]->delete_at_day * 86400 <= time()) {
                # Log deletion
                $c->app->log->info('[DELETION] '.$ip.' tried to view '.$images[0]->filename.' but it has been removed by expiration (path: '.$images[0]->path.')');

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
                # Update counter and check provisionning
                $c->on(finish => sub {
                    # Log access
                    $c->app->log->info('[VIEW] '.$ip.' viewed '.$images[0]->filename.' (path: '.$images[0]->path.')');

                    # Update record
                    my $counter = $images[0]->counter + 1;
                    $images[0]->update(counter => $counter);

                    $images[0]->update(last_access_at => time());
                    $images[0]->update(last_access_by => $ip);

                    # Delete image if needed
                    if ($images[0]->delete_at_first_view) {
                        # Log deletion
                        $c->app->log->info('[DELETION] '.$ip.' made '.$images[0]->filename.' removed (path: '.$images[0]->path.')');

                        # Delete image
                        unlink $images[0]->path();
                        $images[0]->update(enabled => 0);
                    }

                    shift->provisionning();
                });
            }
        } else {
            @images = LutimModel::Lutim->select('WHERE short = ? AND ENABLED = 0 AND path IS NOT NULL', $short);

            if (scalar(@images)) {
                # Log access try
                $c->app->log->info('[NOT FOUND] '.$ip.' tried to view '.$short.' but it does\'nt exist.');

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
