# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lutim::DB::Image;
use bytes;
use Mojo::Base -base;
use Mojo::File;
use Crypt::CBC;
use File::Temp qw(tempfile);

has 'short';
has 'path';
has 'footprint';
has 'enabled';
has 'mediatype';
has 'filename';
has 'counter' => 0;
has 'delete_at_first_view';
has 'delete_at_day';
has 'created_at';
has 'created_by';
has 'last_access_at';
has 'mod_token';
has 'width';
has 'height';
has 'iv';
has 'app';

=encoding utf8

=head1 NAME

Lutim::DB::Image - DB abstraction layer for Lutim images

=head1 Contributing

When creating a new database accessor, make sure that it provides the following subroutines.
After that, modify this file and modify the C<new> subroutine to allow to use your accessor.

Have a look at Lutim::DB::Image::SQLite's code: it's simple and may be more understandable that this doc.

=head1 Attributes

=over 1

=item B<short>                : random string

=item B<path>                 : string, path to the image, relative to lutim's installation directory

=item B<footprint>            : string, sha512 checksum of the image

=item B<enabled>              : boolean, is the image accessible?

=item B<mediatype>            : string, mimetype of the image

=item B<filename>             : string

=item B<counter>              : integer

=item B<delete_at_first_view> : boolean

=item B<delete_at_day>        : integer, number of days from image upload to deletion

=item B<created_at>           : unix timestamp

=item B<created_by>           : unix timestamp

=item B<last_access_at>       : unix timestamp

=item B<mod_token>            : random string

=item B<width>                : integer

=item B<height>               : integer

=item B<iv>                   : initialization vector for the file encryption

=item B<app>                  : a mojolicious object

=back

=head1 Sub routines

=head2 new

=over 1

=item B<Usage>     : C<$c = Lutim::DB::Image-E<gt>new(app =E<gt> $self);>

=item B<Arguments> : any of the attribute above

=item B<Purpose>   : construct a new db accessor object. If the C<short> attribute is provided, it have to load the informations from the database.

=item B<Returns>   : the db accessor object

=item B<Info>      : the app argument is used by Lutim::DB::Image to choose which db accessor will be used, you don't need to use it in new(), but you can use it to access helpers or configuration settings in the other subroutines

=back

=cut

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    if (ref($c) eq 'Lutim::DB::Image') {
        my $dbtype = $c->app->config('dbtype');
        if ($dbtype eq 'sqlite') {
            use Lutim::DB::Image::SQLite;
            $c = Lutim::DB::Image::SQLite->new(@_);
        } elsif ($dbtype eq 'postgresql') {
            use Lutim::DB::Image::Pg;
            $c = Lutim::DB::Image::Pg->new(@_);
        }
    }

    return $c;
}

sub to_hash {
    my $c = shift;

    return {
        short                => $c->short,
        path                 => $c->path,
        footprint            => $c->footprint,
        enabled              => $c->enabled,
        mediatype            => $c->mediatype,
        filename             => $c->filename,
        counter              => $c->counter,
        delete_at_first_view => $c->delete_at_first_view,
        delete_at_day        => $c->delete_at_day,
        created_at           => $c->created_at,
        created_by           => $c->created_by,
        last_access_at       => $c->last_access_at,
        mod_token            => $c->mod_token,
        width                => $c->width,
        height               => $c->height,
        iv                   => $c->iv
    };
}

=head2 accessed

=over 1

=item B<Usage>     : C<$c-E<gt>accessed($time)>

=item B<Arguments> : an unix timestamp

=item B<Purpose>   : increments the counter attribute by one, set the last_access_at attribute to $time and update the database

=item B<Returns>   : the db accessor object

=back

=head2 count_delete_at_day_endis

=over 1

=item B<Usage>     : C<$c-E<gt>count_delete_at_day_endis($delete_at_day, $enabled, [$time])>

=item B<Arguments> : two mandatory parameters: one integer, the delete_at_day attribute, a boolean (0 or 1), the enabled attribute and an optional parameter: an unix timestamp.

=item B<Purpose>   : count how many images there are with the given delete_at_day attribute, and enabled or disabled, depending on the given enabled attribute. If the optional parameter is given, count only images according to the given mandatory parameters that were created before the timestamp

=item B<Returns>   : integer

=back

=head2 count_created_before

=over 1

=item B<Usage>     : C<$c-E<gt>count_created_before($time)>

=item B<Arguments> : an unix timestamp

=item B<Purpose>   : count how many images have been created before the given timestamp

=item B<Returns>   : integer

=back

=head2 select_created_after

=over 1

=item B<Usage>     : C<$c-E<gt>select_created_after($time)>

=item B<Arguments> : an unix timestamp

=item B<Purpose>   : select images created after the given timestamp

=item B<Returns>   : a Mojo::Collection object containing the images created after the given timestamp

=back

=head2 select_empty

=over 1

=item B<Usage>     : C<$c-E<gt>select_empty>

=item B<Arguments> : none

=item B<Purpose>   : select a ready-to-use empty record

=item B<Returns>   : a db accessor object

=back

=head2 write

=over 1

=item B<Usage>     : C<$c-E<gt>write>

=item B<Arguments> : none

=item B<Purpose>   : create or update a record in the database, with the values of the object's attributes

=item B<Returns>   : the db accessor object

=back

=head2 count_short

=over 1

=item B<Usage>     : C<$c-E<gt>count_short($short)>

=item B<Arguments> : a random string, unique image identifier in the database

=item B<Purpose>   : checks that an identifier isn't already used

=item B<Returns>   : integer, number of records having this identifier (should be 0 or 1)

=back

=head2 count_empty

=over 1

=item B<Usage>     : C<$c-E<gt>count_empty>

=item B<Arguments> : none

=item B<Purpose>   : counts the number of records whose path is null

=item B<Returns>   : integer

=back

=head2 count_not_empty

=over 1

=item B<Usage>     : C<$c-E<gt>count_not_empty>

=item B<Arguments> : none

=item B<Purpose>   : counts the number of records whose path is not null

=item B<Returns>   : integer

=back

=head2 clean_ips_until

=over 1

=item B<Usage>     : C<$c-E<gt>clean_ips_until($time)>

=item B<Arguments> : unix timestamp

=item B<Purpose>   : remove the image's sender information on images created before the given timestamp

=item B<Returns>   : the db accessor object

=back

=head2 get_no_longer_viewed_files

=over 1

=item B<Usage>     : C<$c-E<gt>get_no_longer_viewed_files($time)>

=item B<Arguments> : unix timestamp

=item B<Purpose>   : get images no longer viewed after the given timestamp

=item B<Returns>   : a Mojo::Collection object containing the no longer viewed images as Lutim::DB::Image objects

=back

=head2 get_images_to_clean

=over 1

=item B<Usage>     : C<$c-E<gt>get_images_to_clean>

=item B<Arguments> : none

=item B<Purpose>   : get images that are expired but not marked as it

=item B<Returns>   : a Mojo::Collection object containing the images to clean as Lutim::DB::Image objects

=back

=head2 get_50_oldest

=over 1

=item B<Usage>     : C<$c-E<gt>get_50_oldest>

=item B<Arguments> : none

=item B<Purpose>   : get the 50 oldest enabled images

=item B<Returns>   : a Mojo::Collection object containing the 50 oldest enabled images as Lutim::DB::Image objects

=back

=head2 disable

=over 1

=item B<Usage>     : C<$c-E<gt>disable>

=item B<Arguments> : none

=item B<Purpose>   : change the attribute C<enabled> to false and update the database record

=item B<Returns>   : the db accessor object

=back

=head2 search_created_by

=over 1

=item B<Usage>     : C<$c-E<gt>search_created_by($ip)>

=item B<Arguments> : an IP address

=item B<Purpose>   : get enabled images that have been uploaded by this IP address (database query: LIKE '$ip%', results may include images uploaded by similar IP addresses)

=item B<Returns>   : a Mojo::Collection object containing the matching images as Lutim::DB::Image objects

=back

=head2 store

=over 1

=item B<Usage>     : C<$c-E<gt>store($upload)>

=item B<Arguments> : a Mojo::Upload object

=item B<Purpose>   : will store the content to the object’s path, either on filesystem or on Swift object storage

=item B<Returns>   : the db accessor object

=back

=cut

sub store {
    my $c      = shift;
    my $upload = shift;

    if ($c->app->config('swift')) {
        $c->app->swift->put_object(
            container_name => $c->app->config('swift')->{container},
            object_name    => $c->path,
            content_length => $upload->size,
            content        => $upload->slurp
        );
    } else {
        $upload->move_to($c->path);
    }

    return $c;
}

=head2 retrieve

=over 1

=item B<Usage>     : C<$c-E<gt>retrieve>

=item B<Arguments> : none

=item B<Purpose>   : get file from storage, either filesystem or Swift object storage

=item B<Returns>   : the data from the file

=back

=cut

sub retrieve {
    my $c      = shift;
    my $upload = shift;

    if ($c->app->config('swift')) {
        my $file;
        $c->app->swift->get_object(
            container_name => $c->app->config('swift')->{container},
            object_name    => $c->path,
            write_code => sub {
                my ($status, $message, $headers, $chunk) = @_;
                $file .= $chunk;
            }
        );
        return $file;
    } else {
        return Mojo::File->new($c->path)->slurp;
    }
}

=head2 decrypt

=over 1

=item B<Usage>     : C<$c-E<gt>decrypt($key)>

=item B<Arguments> : the decryption key

=item B<Purpose>   : decrypt the image

=item B<Returns>   : a Mojo::Asset::File object

=back

=cut

sub decrypt {
    my $c    = shift;
    my $key  = shift;
    $c->iv = 'dupajasi' unless $c->iv;

    my $cipher = Crypt::CBC->new(
        -key    => $key,
        -cipher => 'Blowfish',
        -header => 'none',
        -iv     => $c->iv
    );

    $cipher->start('decrypting');

    my $decrypt_asset = Mojo::Asset::File->new;

    if ($c->app->config('swift')) {
        $c->app->swift->get_object(
            container_name => $c->app->config('swift')->{container},
            object_name    => $c->path,
            write_code     => sub {
                my ($status, $message, $headers, $chunk) = @_;
                $decrypt_asset->add_chunk($cipher->crypt($chunk));
            }
        );
    } else {
        open(my $f, "<", $c->path) or die "Unable to read encrypted file: $!";
        binmode $f;
        while (read($f, my $buffer, 1024)) {
              $decrypt_asset->add_chunk($cipher->crypt($buffer));
        }
        $decrypt_asset->add_chunk($cipher->finish);

    }
    return $decrypt_asset->slurp;
}

=head2 delete

=over 1

=item B<Usage>     : C<$c-E<gt>delete>

=item B<Arguments> : none

=item B<Purpose>   : delete the file on filesystem or Swift object storage and disable the image in database

=item B<Returns>   : the db accessor object

=back

=cut

sub delete {
    my $c   = shift;
    if ($c->app->config('cache_max_size') != 0 || scalar(@{$c->app->config('memcached_servers')})) {
        $c->app->chi('lutim_images_cache')->remove($c->short);
    }
    if ($c->app->config('swift')) {
        $c->app->swift->delete_object({
            container_name => $c->app->config('swift')->{container},
            object_name    => $c->path
        });
    } else {
        unlink $c->path or warn "Could not unlink ".$c->path.": $!";
    }
    return $c->disable();
}
1;
