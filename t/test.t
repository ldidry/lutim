# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
use Mojo::Base -strict;
use Mojo::File;
use Mojo::JSON qw(true false);
use Mojolicious;

use Test::More;
use Test::Mojo;

use FindBin qw($Bin);
use Digest::file qw(digest_file_hex);

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
                provisioning      => 100,
                provis_step       => 5,
                length            => 8,
                always_encrypt    => 0,
                anti_flood_delay  => 5,
                tweet_card_via    => '@framasky',
                max_file_size     => 10*1024*1024,
                https             => 0,
                proposed_delays   => '0,1,7,30,365',
                default_delay     => 0,
                max_delay         => 0,
                token_length      => 24,
                crypto_key_length => 8,
                thumbnail_size    => 100,
                theme             => 'default',
                dbtype            => 'sqlite',
                db_path           => 'lutim.db',
                max_files_in_zip  => 15,
                prefix            => '/',
                minion            => {
                    enabled => 0,
                    dbtype  => 'sqlite',
                    db_path => 'minion.db'
                },
                cache_max_size    => 0,
                quiet_logs        => 0,
                disable_img_stats => 0,
            }
        }
    );
    $m->plugin('Lutim::Plugin::Helpers');
}

# Home page
my $t = Test::Mojo->new('Lutim');
$t->get_ok('/')
  ->status_is(200)
  ->content_like(qr/Let's Upload That IMage/i);

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
      '/max_file_size'     => 1048576
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
