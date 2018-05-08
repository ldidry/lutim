package Lutim::Plugin::Headers;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ($self, $app) = @_;

    # Assets Cache headers
    $app->plugin('StaticCache' => { even_in_dev => 1 });

    # Add CSP Header
    if (!defined($app->config('csp')) || (defined($app->config('csp')) && $app->config('csp') ne '')) {
        my $directives = {
            'default-src'     => "'none'",
            'script-src'      => "'self' 'unsafe-eval'",
            'style-src'       => "'self' 'unsafe-inline'",
            'connect-src'     => "'self'",
            'img-src'         => "'self' data:",
            'font-src'        => "'self'",
            'form-action'     => "'self'",
            'base-uri'        => "'self'",
        };

        my $frame_ancestors = '';
        #$frame_ancestors = "'none'" if $app->config('x_frame_options') eq 'DENY';
        #$frame_ancestors = "'self'" if $app->config('x_frame_options') eq 'SAMEORIGIN';
        #if ($app->config('x_frame_options') =~ m#^ALLOW-FROM#) {
        #    $frame_ancestors = $app->config('x_frame_options');
        #    $frame_ancestors =~ s#ALLOW-FROM +##;
        #}
        $directives->{'frame-ancestors'} = $frame_ancestors if $frame_ancestors;

        $app->plugin('CSPHeader',
            csp        => $app->config('csp'),
            directives => $directives
        );
    }
}

1;
