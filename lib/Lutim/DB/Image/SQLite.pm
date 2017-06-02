# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lutim::DB::Image::SQLite;
use Mojo::Base 'Lutim::DB::Image';
use Lutim::DB::SQLite;
use Mojo::Collection 'c';

has 'record';

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
        return Lutim::DB::SQLite::Lutim->count('WHERE path IS NOT NULL AND delete_at_day = ? AND enabled = ? AND created_at < ?', $day, $enabled, $created);
    } else {
        return Lutim::DB::SQLite::Lutim->count('WHERE path IS NOT NULL AND delete_at_day = ? AND enabled = ?', $day, $enabled);
    }
}

sub count_created_before {
    my $c    = shift;
    my $time = shift;

    return Lutim::DB::SQLite::Lutim->count('WHERE path IS NOT NULL AND created_at < ?', $time);
}

sub select_created_after {
    my $c    = shift;
    my $time = shift;

    my @images;

    my @records = Lutim::DB::SQLite::Lutim->select('WHERE path IS NOT NULL AND created_at >= ?', $time);

    for my $e (@records) {
        my $i = Lutim::DB::Image->new(app => $c->app);
        $i->record($e);
        $i->_slurp;

        push @images, $i;
    }

    return c(@images);
}

sub select_empty {
    my $c = shift;

    my @records = Lutim::DB::SQLite::Lutim->select('WHERE path IS NULL LIMIT 1');

    $c->record($records[0]);
    $c = $c->_slurp;

    return $c;
}

sub write {
    my $c = shift;

    if ($c->record) {
        $c->record->update(
            counter              => $c->counter,
            created_at           => $c->created_at,
            created_by           => $c->created_by,
            delete_at_day        => $c->delete_at_day,
            delete_at_first_view => $c->delete_at_first_view,
            enabled              => $c->enabled,
            filename             => $c->filename,
            footprint            => $c->footprint,
            height               => $c->height,
            last_access_at       => $c->last_access_at,
            mediatype            => $c->mediatype,
            mod_token            => $c->mod_token,
            path                 => $c->path,
            short                => $c->short,
            width                => $c->width
        );
    } else {
        my $record = Lutim::DB::SQLite::Lutim->create(
            counter              => $c->counter,
            created_at           => $c->created_at,
            created_by           => $c->created_by,
            delete_at_day        => $c->delete_at_day,
            delete_at_first_view => $c->delete_at_first_view,
            enabled              => $c->enabled,
            filename             => $c->filename,
            footprint            => $c->footprint,
            height               => $c->height,
            last_access_at       => $c->last_access_at,
            mediatype            => $c->mediatype,
            mod_token            => $c->mod_token,
            path                 => $c->path,
            short                => $c->short,
            width                => $c->width
        );
        $c->record($record);
    }

    return $c;
}

sub count_short {
    my $c     = shift;
    my $short = shift;

    return Lutim::DB::SQLite::Lutim->count('WHERE short IS ?', $short);
}

sub count_empty {
    my $c = shift;

    return Lutim::DB::SQLite::Lutim->count('WHERE path IS NULL');
}

sub count_not_empty {
    my $c = shift;

    return Lutim::DB::SQLite::Lutim->count('WHERE path IS NOT NULL');
}

sub clean_ips_until {
    my $c    = shift;
    my $time = shift;

    Lutim::DB::SQLite->do(
        'UPDATE lutim SET created_by = "" WHERE path IS NOT NULL AND created_at < ?',
        {},
        $time
    );

    return $c;
}

sub get_no_longer_viewed_files {
    my $c    = shift;
    my $time = shift;

    my @images;

    my @records = Lutim::DB::SQLite::Lutim->select('WHERE enabled = 1 AND last_access_at < ?', $time);

    for my $e (@records) {
        my $i = Lutim::DB::Image->new(app => $c->app);
        $i->record($e);
        $i->_slurp;

        push @images, $i;
    }

    return c(@images);
}

sub get_images_to_clean {
    my $c = shift;

    my @images;

    my @records = Lutim::DB::SQLite::Lutim->select('WHERE enabled = 1 AND (delete_at_day * 86400) < (? - created_at) AND delete_at_day != 0', time());

    for my $e (@records) {
        my $i = Lutim::DB::Image->new(app => $c->app);
        $i->record($e);
        $i->_slurp;

        push @images, $i;
    }

    return c(@images);
}

sub get_50_oldest {
    my $c = shift;

    my @images;

    my @records = Lutim::DB::SQLite::Lutim->select('WHERE path IS NOT NULL AND enabled = 1 ORDER BY created_at ASC LIMIT 50');

    for my $e (@records) {
        my $i = Lutim::DB::Image->new(app => $c->app);
        $i->record($e);
        $i->_slurp;

        push @images, $i;
    }

    return c(@images);
}

sub disable {
    my $c = shift;

    $c->record->update(enabled => 0);
    $c->enabled(0);

    return $c;
}

sub _slurp {
    my $c = shift;

    my @images;
    if ($c->record) {
        @images = ($c->record);
    } elsif ($c->short) {
        @images = Lutim::DB::SQLite::Lutim->select('WHERE short = ?', $c->short);
    }

    if (scalar @images) {
        $c->short($images[0]->short);
        $c->path($images[0]->path);
        $c->footprint($images[0]->footprint);
        $c->enabled($images[0]->enabled);
        $c->mediatype($images[0]->mediatype);
        $c->filename($images[0]->filename);
        $c->counter($images[0]->counter);
        $c->delete_at_first_view($images[0]->delete_at_first_view);
        $c->delete_at_day($images[0]->delete_at_day);
        $c->created_at($images[0]->created_at);
        $c->created_by($images[0]->created_by);
        $c->last_access_at($images[0]->last_access_at);
        $c->mod_token($images[0]->mod_token);
        $c->width($images[0]->width);
        $c->height($images[0]->height);

        $c->record($images[0]) unless $c->record;
    }

    return $c;
}

1;
