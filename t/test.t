# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
use Mojo::Base -strict;
use Mojo::File;
use Mojo::JSON qw(true false);
use Mojolicious;

use Test::More;
use Test::Mojo;

use FindBin qw($Bin);
use Digest::file qw(digest_file_hex);
use IO::Uncompress::Unzip qw($UnzipError);

my ($m, $cfile);

BEGIN {
    use lib 'lib';
    $m = Mojolicious->new;
    $cfile = Mojo::File->new($Bin, '..' , 'lutim.conf');
    if (defined $ENV{MOJO_CONFIG}) {
        $cfile = Mojo::File->new($ENV{MOJO_CONFIG});
        unless (-e $cfile->to_abs) {
            $cfile = Mojo::File->new($Bin, '..', $ENV{MOJO_CONFIG});
        }
    }
    my $config = $m->plugin('Config' =>
        {
            file    => $cfile->to_abs->to_string,
            default => {
                provisioning           => 100,
                provis_step            => 5,
                length                 => 8,
                always_encrypt         => 0,
                anti_flood_delay       => 5,
                max_file_size          => 10*1024*1024,
                https                  => 0,
                proposed_delays        => '0,1,7,30,365',
                default_delay          => 0,
                max_delay              => 0,
                token_length           => 24,
                crypto_key_length      => 8,
                thumbnail_size         => 100,
                theme                  => 'default',
                dbtype                 => 'sqlite',
                db_path                => 'lutim.db',
                max_files_in_zip       => 15,
                prefix                 => '/',
                minion                 => {
                    enabled => 0,
                    dbtype  => 'sqlite',
                    db_path => 'minion.db'
                },
                cache_max_size         => 0,
                memcached_servers      => [],
                quiet_logs             => 0,
                disable_img_stats      => 0,
                x_frame_options        => 'DENY',
                x_content_type_options => 'nosniff',
                x_xss_protection       => '1; mode=block',
            }
        }
    );
    $m->plugin('Lutim::Plugin::Helpers');
}

# Home page
my $t = Test::Mojo->new('Lutim');
$t->get_ok('/')
  ->status_is(200)
  ->content_like(qr/Let's Upload That IMage/i)
  ->header_is('Content-Security-Policy' => "base-uri 'self'; connect-src 'self'; default-src 'none'; font-src 'self'; form-action 'self'; frame-ancestors 'none'; img-src 'self' data:; script-src 'self' 'unsafe-eval'; style-src 'self' 'unsafe-inline'")
  ->header_is('X-Frame-Options' => 'DENY')
  ->header_is('X-XSS-Protection' => '1; mode=block')
  ->header_is('X-Content-Type-Options' => 'nosniff');

# Gzip static assets
$t->get_ok('/css/lutim.css')
  ->status_is(200)
  ->header_is(Vary => 'Accept-Encoding');

# Instance settings informations
$t->get_ok('/infos')
  ->status_is(200)
  ->json_has('image_magick')
  ->json_is(
      '/always_encrypt'    => false,
      '/broadcast_message' => 'test broadcast message',
      '/contact'           => 'John Doe, admin[at]example.com',
      '/default_delay'     => 30,
      '/max_delay'         => 200,
      '/max_file_size'     => 1048576,
      '/upload_enabled'    => true
  );

# Post image
my $image = Mojo::File->new($Bin, '..', 'themes', 'default', 'public', 'img', 'Lutim.png')->to_string;
$t->post_ok('/' => form => { file => { file => $image }, format => 'json' })
  ->status_is(200)
  ->json_has('msg', 'success')
  ->json_is('/success' => true, '/msg/filename' => 'Lutim.png')
  ->json_like('/msg/short' => qr#[-_a-zA-Z0-9]{8}#, '/msg/real_short' => qr#[-_a-zA-Z0-9]{8}#, '/msg/token' => qr#[-_a-zA-Z0-9]{24}#);

# Post delete-at-first-view image
my $raw   = $t->ua->post('/' => form => { file => { file => $image }, 'first-view' => 1, format => 'json' })->res;
my $short = $raw->json('/msg/short');

$t->get_ok('/'.$short)
  ->status_is(200);

$t->get_ok('/'.$short)
  ->status_is(302);

# Get zip file and test it
$t->get_ok('/zip?i='.$short)
  ->status_is(200)
  ->header_is('Content-Disposition' => 'attachment;filename=images.zip');

my $zip = $t->ua->get('/zip?i='.$short)->res->body;
my $u = new IO::Uncompress::Unzip \$zip
    or die "Cannot open zip file: $UnzipError";

my $status;
my @files = qw(hosted_with_lutim.png images/ images/Lutim.png.txt);
for ($status = 1; $status > 0; $status = $u->nextStream()) {
    my $name = $u->getHeaderInfo()->{Name};
    is($name, shift(@files));
    my $buff;
    while (($status = $u->read($buff)) > 0) {
    }
    last if $status < 0;
}

# Delete image with token
$raw       = $t->ua->post('/' => form => { file => { file => $image }, format => 'json' })->res;
my $rshort = $raw->json('/msg/real_short');
my $token  = $raw->json('/msg/token');

$t->get_ok('/'.$rshort)
  ->status_is(200);

$t->get_ok('/d/'.$rshort.'/'.$token, form => { format => 'json' })
  ->status_is('200')
  ->json_is(
      {
          success => true,
          msg     => 'The image Lutim.png has been successfully deleted'
      }
  );

$t->get_ok('/'.$rshort)
  ->status_is(302);

# Needed if we use Minion with sqlite for increasing counters
sleep 8;

# Get image counter
$t->post_ok('/c', form => { short => $rshort, token => $token })
  ->status_is(200)
  ->json_is(
      {
          success => true,
          counter => 1,
          enabled => false
      }
  );

done_testing();
