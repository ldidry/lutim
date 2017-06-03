# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lutim::DB::Image::Pg;
use Mojo::Base 'Lutim::DB::Image';
use Mojo::Collection 'c';

has 'record' => 0;

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);
    $c = $c->_slurp if ($c->short);

    return $c;
}

sub count_delete_at_day_endis {
    my $c       = shift;
    my $day     = shift;
    my $enabled = shift;
    my $created = shift;

    if (defined $created) {
        return $c->app->pg->db->query('SELECT count(short) FROM lutim WHERE path IS NOT NULL AND delete_at_day = ? AND enabled = ? AND created_at < ?', $day, $enabled, $created)->hashes->first->{count};
    } else {
        return $c->app->pg->db->query('SELECT count(short) FROM lutim WHERE path IS NOT NULL AND delete_at_day = ? AND enabled = ?', $day, $enabled)->hashes->first->{count};
    }
}

sub count_created_before {
    my $c    = shift;
    my $time = shift;

    return $c->app->pg->db->query('SELECT count(short) FROM lutim WHERE path IS NOT NULL AND created_at < ?', $time)->hashes->first->{count};
}

sub select_created_after {
    my $c    = shift;
    my $time = shift;

    my @images;

    my $records = $c->app->pg->db->query('SELECT * FROM lutim WHERE path IS NOT NULL AND created_at >= ?', $time)->hashes;

    $records->each(
        sub {
            my ($e, $num) = @_;
            my $i = Lutim::DB::Image->new(app => $c->app);
            $i->record(1);
            $i->_slurp;

            push @images, $i;
        }
    );

    return c(@images);
}

sub select_empty {
    my $c = shift;

    my $record = $c->app->pg->db->query('SELECT * FROM lutim WHERE path IS NULL LIMIT 1')->hashes->first;

    $c->record(1);
    $c = $c->_slurp;

    return $c;
}

sub write {
    my $c = shift;

    if ($c->record) {
        $c->app->pg->db->query('UPDATE lutim SET counter = ?, created_at = ?, created_by = ?, delete_at_day = ?, delete_at_first_view = ?, enabled = ?, filename = ?, footprint = ?, height = ?, last_access_at = ?, mediatype = ?, mod_token = ?, path = ?, short = ?, width = ? WHERE short = ?', $c->counter, $c->created_at, $c->created_by, $c->delete_at_day, $c->delete_at_first_view, $c->enabled, $c->filename, $c->footprint, $c->height, $c->last_access_at, $c->mediatype, $c->mod_token, $c->path, $c->short, $c->width, $c->short);
    } else {
        $c->app->pg->db->query('INSERT INTO lutim (counter, created_at, created_by, delete_at_day, delete_at_first_view, enabled, filename, footprint, height, last_access_at, mediatype, mod_token, path, short, width) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', $c->counter, $c->created_at, $c->created_by, $c->delete_at_day, $c->delete_at_first_view, $c->enabled, $c->filename, $c->footprint, $c->height, $c->last_access_at, $c->mediatype, $c->mod_token, $c->path, $c->short, $c->width);
        $c->record(1);
    }

    return $c;
}

sub count_short {
    my $c     = shift;
    my $short = shift;

    return $c->app->pg->db->query('SELECT count(short) FROM lutim WHERE short IS ?', $short)->hashes->first->{count};
}

sub count_empty {
    my $c = shift;

    return $c->app->pg->db->query('SELECT count(short) FROM lutim WHERE path IS NULL')->hashes->first->{count};
}

sub count_not_empty {
    my $c = shift;

    return $c->app->pg->db->query('SELECT count(short) FROM lutim WHERE path IS NOT NULL')->hashes->first->{count};
}

sub clean_ips_until {
    my $c    = shift;
    my $time = shift;

    $c->app->pg->db->query('UPDATE lutim SET created_by = "" WHERE path IS NOT NULL AND created_at < ?', $time);

    return $c;
}

sub get_no_longer_viewed_files {
    my $c    = shift;
    my $time = shift;

    my @images;

    my $records = $c->app->pg->db->query('SELECT * FROM lutim WHERE enabled = 1 AND last_access_at < ?', $time)->{hashes};

    $records->each(
        sub {
            my ($e, $num) = @_;
            my $i = Lutim::DB::Image->new(app => $c->app);
            $i->record(1);
            $i->_slurp;

            push @images, $i;
        }
    );

    return c(@images);
}

sub get_images_to_clean {
    my $c = shift;

    my @images;

    my $records = $c->app->pg->db->query('SELECT * FROM lutim WHERE enabled = 1 AND (delete_at_day * 86400) < (? - created_at) AND delete_at_day != 0', time())->hashes;

    $records->each(
        sub {
            my ($e, $num) = @_;
            my $i = Lutim::DB::Image->new(app => $c->app);
            $i->record(1);
            $i->_slurp;

            push @images, $i;
        }
    );

    return c(@images);
}

sub get_50_oldest {
    my $c = shift;

    my @images;

    my $records = $c->app->pg->db->query('SELECT * FROM lutim WHERE path IS NOT NULL AND enabled = 1 ORDER BY created_at ASC LIMIT 50')->hashes;

    $records->each(
        sub {
            my ($e, $num) = @_;
            my $i = Lutim::DB::Image->new(app => $c->app);
            $i->record(1);
            $i->_slurp;

            push @images, $i;
        }
    );

    return c(@images);
}

sub disable {
    my $c = shift;

    $c->app->pg->db->query('UPDATE lutim SET enabled = 0 WHERE short = ?', $c->short);
    $c->enabled(0);

    return $c;
}

sub _slurp {
    my $c = shift;

    my $images = $c->app->pg->db->query('SELECT * FROM lutim WHERE short = ?', $c->short)->hashes;

    if ($images->size) {
        my $image = $images->first;

        $c->short($image->{short});
        $c->path($image->{path});
        $c->footprint($image->{footprint});
        $c->enabled($image->{enabled});
        $c->mediatype($image->{mediatype});
        $c->filename($image->{filename});
        $c->counter($image->{counter});
        $c->delete_at_first_view($image->{delete_at_first_view});
        $c->delete_at_day($image->{delete_at_day});
        $c->created_at($image->{created_at});
        $c->created_by($image->{created_by});
        $c->last_access_at($image->{last_access_at});
        $c->mod_token($image->{mod_token});
        $c->width($image->{width});
        $c->height($image->{height});

        $c->record(1);
    }

    return $c;
}

1;
