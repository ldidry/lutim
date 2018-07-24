# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lutim::Command::image;
use Mojo::Base 'Mojolicious::Command';
use Mojo::Util qw(getopt);
use Mojo::Collection 'c';
use Lutim::DB::Image;
use FindBin qw($Bin);
use File::Spec qw(catfile);

has description => 'Manage stored images';
has usage => sub { shift->extract_usage };

my $csv_header = 0;

sub run {
    my $c    = shift;
    my @args = @_;

    my $cfile = Mojo::File->new($Bin, '..' , 'lutim.conf');
    if (defined $ENV{MOJO_CONFIG}) {
        $cfile = Mojo::File->new($ENV{MOJO_CONFIG});
        unless (-e $cfile->to_abs) {
            $cfile = Mojo::File->new($Bin, '..', $ENV{MOJO_CONFIG});
        }
    }
    my $config = $c->app->plugin('Config', {
        file    => $cfile,
        default =>  {
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
    });

    if (scalar(@{$config->{memcached_servers}})) {
        $c->app->plugin(CHI => {
            lutim_images_cache => {
                driver             => 'Memcached',
                servers            => $config->{memcached_servers},
                expires_in         => '1 day',
                expires_on_backend => 1,
            }
        });
    }

    getopt \@args,
      'i|info=s{1,}'   => \my @info,
      'c|csv'          => \my $csv,
      'r|remove=s{1,}' => \my @remove,
      'y|yes'          => \my $yes,
      'q|quiet'        => \my $quiet,
      's|search=s'     => \my $ip
    ;

    if (scalar @info) {
        c(@info)->each(
            sub {
                my ($e, $num) = @_;
                my $i = get_short($c, $e);
                print_infos($i, $csv) if $i;
            }
        );
    }
    if (scalar @remove) {
        c(@remove)->each(
            sub {
                my ($e, $num) = @_;
                my $i = get_short($c, $e);
                if ($i) {
                    if ($i->enabled) {
                        print_infos($i, 0) unless $quiet;
                        delete_short($c, $i, $yes);
                    } else {
                        say sprintf('The image %s is already disabled', $e);
                    }
                }
            }
        );
        if ($config->{cache_max_size} && !scalar(@{$config->{memcached_servers}})) {
            say "\nPlease reload Lutim to be sure that the deleted images are not in the cache anymore.";
        }
    }
    if ($ip) {
        my $u = Lutim::DB::Image->new(app => $c->app)->search_created_by($ip);
        my @shorts;
        $u->each(sub {
            my ($e, $num) = @_;
            push @shorts, $e->short;
            print_infos($e, $csv);
        });
        say sprintf('%d matching URLs', $u->size);
        say sprintf("If you want to delete those images, please do:\n  carton exec script/lutim image --remove %s", join(' ', @shorts)) if @shorts;
    }
}

sub get_short {
    my $c     = shift;
    my $short = shift;

    my $i = Lutim::DB::Image->new(app => $c->app, short => $short);
    if ($i->path) {
        return $i;
    } else {
        say sprintf('Sorry, unable to find an image with short = %s', $short);
        return undef;
    }
}

sub print_infos {
    my $i   = shift;
    my $csv = shift;

    my $msg;

    if ($i) {
        if ($csv) {
            if (!$csv_header) {
                say 'short,path,footprint,enabled,mediatype,filename,counter,delete_at_first_view,delete_at_day,created_at,created_by,last_access_at,width,height';
                $csv_header = 1;
            }
            $msg = '"%s","%s","%s",%d,"%s","%s",%d,"%s",%d,"%s","%s","%s",%d,%d';
        } else {
            $msg = <<EOF;
%s
    path                 : %s
    footprint            : %s
    enabled              : %d
    mediatype            : %s
    filename             : %s
    counter              : %d
    delete_at_first_view : %d
    delete_at_day        : %d
    created_at           : %s
    created_by           : %s
    last_access_at       : %s
    width                : %d
    height               : %d
EOF
        }
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($i->created_at);
        my $created_at = sprintf('%d-%d-%d %d:%d:%d GMT', $year + 1900, ++$mon, $mday, $hour, $min, $sec);

        my $last_access_at = '';
        if ($i->last_access_at) {
            ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)    = gmtime($i->last_access_at);
            $last_access_at = sprintf('%d-%d-%d %d:%d:%d GMT', $year + 1900, ++$mon, $mday, $hour, $min, $sec);
        }
        say sprintf($msg,
            $i->short,
            $i->path,
            $i->footprint,
            $i->enabled,
            $i->mediatype,
            $i->filename,
            $i->counter,
            $i->delete_at_first_view,
            $i->delete_at_day,
            $created_at,
            $i->created_by,
            $last_access_at,
            $i->width,
            $i->height
        );
    }
}

sub delete_short {
    my $c = shift;
    my $i = shift;
    my $y = shift;

    my $confirm = ($y) ? 'yes' : undef;
    unless (defined $confirm) {
        printf('Are you sure you want to remove this image (%s) ? [N/y] ', $i->short);
        $confirm = <STDIN>;
        chomp $confirm;
    }
    if ($confirm =~ m/^y(es)?$/i) {
        $c->app->delete_image($i);
    } else {
        say 'Answer was not "y" or "yes". Aborting deletion.';
    }
}

=encoding utf8

=head1 NAME

Lutim::Command::image - Manage URL in Lutim's database

=head1 SYNOPSIS

  Usage:
      carton exec script/lutim image --info <short> <short> [--csv]              Print infos about the space-separated images (--csv creates a CSV output)
      carton exec script/lutim image --remove <short> <short> [--yes] [--quiet]  Delete the space-separated images (--yes disables confirmation, --quiet disables informations printing)
      carton exec script/lutim image --search <ip>                               Print infos about the images uploaded by this IP (database LIKE, may include images uploaded by other IPs)

=cut

1;

