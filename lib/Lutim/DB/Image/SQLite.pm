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

    my @records = c(LutimModel::Lutim->select('WHERE enabled = 1 AND last_access_at < ?', $time));

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

    my @records = c(LutimModel::Lutim->select('WHERE enabled = 1 AND (delete_at_day * 86400) < (? - created_at) AND delete_at_day != 0', time()));

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

    my @records = c(Lutim::DB::SQLite::Lutim->select('WHERE path IS NOT NULL AND enabled = 1 ORDER BY created_at ASC LIMIT 50'));

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

    my @urls;
    if ($c->record) {
        @urls = ($c->record);
    } elsif ($c->short) {
        @urls = Lutim::DB::SQLite::Lutim->select('WHERE short = ?', $c->short);
    }

    if (scalar @urls) {
        $c->short($urls[0]->short);
        $c->path($urls[0]->path);
        $c->footprint($urls[0]->footprint);
        $c->enabled($urls[0]->enabled);
        $c->mediatype($urls[0]->mediatype);
        $c->filename($urls[0]->filename);
        $c->counter($urls[0]->counter);
        $c->delete_at_first_view($urls[0]->delete_at_first_view);
        $c->delete_at_day($urls[0]->delete_at_day);
        $c->created_at($urls[0]->created_at);
        $c->created_by($urls[0]->created_by);
        $c->last_access_at($urls[0]->last_access_at);
        $c->mod_token($urls[0]->mod_token);
        $c->width($urls[0]->width);
        $c->height($urls[0]->height);

        $c->record($urls[0]) unless $c->record;
    }

    return $c;
}

1;
