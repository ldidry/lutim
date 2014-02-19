package Mojolicious::Command::cron::stats;
use Mojo::Base 'Mojolicious::Command';
use LutimModel;
use Mojo::DOM;
use Mojo::Util qw(slurp spurt decode);
use DateTime;
use Mojolicious::Plugin::Config;

has description => 'Generate statistics about LUTIm.';
has usage => sub { shift->extract_usage };

sub run {
    my $c = shift;

    my $config = Mojolicious::Plugin::Config->parse(decode('UTF-8', slurp 'lutim.conf'), 'lutim.conf');
    $config->{stats_day_num} = (defined($config->{stats_day_num})) ? $config->{stats_day_num} : 365;

    my $text     = slurp('templates/data.html.ep.template');
    my $dom      = Mojo::DOM->new($text);
    my $thead_tr = $dom->at('table thead tr');
    my $tbody_tr = $dom->at('table tbody tr');
    my $tbody_t2 = $tbody_tr->next;

    my $separation = time() - $config->{stats_day_num} * 86400;

    my %data;
    for my $img (LutimModel::Lutim->select('WHERE path IS NOT NULL AND created_at > = ?', $separation)) {
        my $time                 = DateTime->from_epoch(epoch => $img->created_at);
        my ($year, $month, $day) = ($time->year(), $time->month(), $time->day());

        if (defined($data{$year}->{$month}->{$day})) {
            $data{$year}->{$month}->{$day} += 1;
        } else {
            $data{$year}->{$month}->{$day} = 1;
        }
    }

    my $total = LutimModel::Lutim->count('WHERE path IS NOT NULL AND created_at < ?', $separation);
    for my $year (sort keys %data) {
        for my $month (sort keys %{$data{$year}}) {
            for my $day (sort keys %{$data{$year}->{$month}}) {
                $thead_tr->append_content('<th>'."$day/$month/$year".'</th>'."\n");
                $tbody_tr->append_content('<td>'.$data{$year}->{$month}->{$day}.'</td>'."\n");
                $total += $data{$year}->{$month}->{$day};
                $tbody_t2->append_content('<td>'.$total.'</td>'."\n");
            }
        }
    }
    spurt $dom, 'templates/data.html.ep';
}

=encoding utf8

=head1 NAME

Mojolicious::Command::cron::stats - Stats generator

=head1 SYNOPSIS

  Usage: script/lutim cron stats

=cut

1;
