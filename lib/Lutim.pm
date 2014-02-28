package Lutim;
use Mojo::Base 'Mojolicious';
use Mojo::Util qw(quote);
use LutimModel;

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
            my ($filename, $path, $mediatype, $dl, $expires, $nocache) = @_;

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
            if ($nocache) {
                $headers->add('Cache-Control'       => 'no-cache');
            } else {
                $headers->add('Expires'             => $expires);
            }
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

    $self->helper(
        max_delay => sub {
            my $c = shift;

            if (defined($c->config->{max_delay})) {
                my $delay = $c->config->{max_delay};
                if ($delay >= 0) {
                    return $delay;
                } else {
                    warn "max_delay set to a negative value. Default to 0."
                }
            }
            return 0;
        }
    );

    $self->helper(
        default_delay => sub {
            my $c = shift;

            if (defined($c->config->{default_delay})) {
                my $delay = $c->config->{default_delay};
                if ($delay >= 0) {
                    return $delay;
                } else {
                    warn "default_delay set to a negative value. Default to 0."
                }
            }
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

    $r->post('/')->
        to('Controller#add')->
        name('add');

    $r->get('/:short')->
        to('Controller#short')->
        name('short');
}

1;
