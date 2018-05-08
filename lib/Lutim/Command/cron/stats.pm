# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lutim::Command::cron::stats;
use Mojo::Base 'Mojolicious::Command';
use Mojo::DOM;
use Mojo::Util qw(encode);
use Mojo::File;
use Mojo::JSON qw(encode_json);
use Lutim::DB::Image;
use DateTime;
use FindBin qw($Bin);
use File::Spec qw(catfile);
use POSIX;

has description => 'Generate statistics about Lutim.';
has usage => sub { shift->extract_usage };

sub run {
    my $c = shift;

    my $cfile = Mojo::File->new($Bin, '..' , 'lutim.conf');
    if (defined $ENV{MOJO_CONFIG}) {
        $cfile = Mojo::File->new($ENV{MOJO_CONFIG});
        unless (-e $cfile->to_abs) {
            $cfile = Mojo::File->new($Bin, '..', $ENV{MOJO_CONFIG});
        }
    }
    my $config = $c->app->plugin('Config', {
        file    => $cfile,
        default => {
            theme         => 'default',
            stats_day_num => 365,
            dbtype        => 'sqlite'
        }
    });

    my $template = 'themes/'.$config->{theme}.'/templates/data.html.ep.template';
    unless (-e $template) {
        $config->{theme} = 'default';
        $template = 'themes/'.$config->{theme}.'/templates/data.html.ep.template';
    }

    my $stats = {};

    my $text     = Mojo::File->new($template)->slurp;
    my $dom      = Mojo::DOM->new($text);
    my $thead_tr = $dom->at('table thead tr');
    my $tbody_tr = $dom->at('table tbody tr');
    my $tbody_t2 = $tbody_tr->next;

    my $separation = time() - $config->{stats_day_num} * 86400;

    my %data;
    my $img = Lutim::DB::Image->new(app => $c->app);
    my $sca = $img->select_created_after($separation);

    $stats->{total}    = $img->count_not_empty;
    $stats->{average}  = floor($sca->size / $config->{stats_day_num}) if $config->{stats_day_num};
    $stats->{for_days} = $config->{stats_day_num};

    $sca->each(
        sub {
            my ($e, $num) = @_;
            my $time                 = DateTime->from_epoch(epoch => $e->created_at);
            my ($year, $month, $day) = ($time->year(), $time->month(), $time->day());

            if (defined($data{$year}->{$month}->{$day})) {
                $data{$year}->{$month}->{$day} += 1;
            } else {
                $data{$year}->{$month}->{$day} = 1;
            }
        }
    );

    my $total = $img->count_created_before($separation);
    for my $year (sort {$a <=> $b} keys %data) {
        for my $month (sort {$a <=> $b} keys %{$data{$year}}) {
            for my $day (sort {$a <=> $b} keys %{$data{$year}->{$month}}) {
                $thead_tr->append_content('<th>'."$day/$month/$year".'</th>'."\n");
                $tbody_tr->append_content('<td>'.$data{$year}->{$month}->{$day}.'</td>'."\n");
                $total += $data{$year}->{$month}->{$day};
                $tbody_t2->append_content('<td>'.$total.'</td>'."\n");
            }
        }
    }

    my $moy = $total / $config->{stats_day_num};

    # Raw datas
    my $template2 = 'themes/'.$config->{theme}.'/templates/raw.html.ep.template';
    unless (-e $template2) {
        $config->{theme} = 'default';
        $template = 'themes/'.$config->{theme}.'/templates/raw.html.ep.template';
    }
    my $text2    = Mojo::File->new($template2)->slurp;
    my $dom2     = Mojo::DOM->new($text2);
    my $raw      = $dom2->at('table tbody');
    my $raw_foot = $dom2->at('table tfoot');
    my $unlimited_enabled      = $img->count_delete_at_day_endis(0,   1);
    my $unlimited_disabled     = $img->count_delete_at_day_endis(0,   0);
    my $day_enabled            = $img->count_delete_at_day_endis(1,   1);
    my $day_disabled           = $img->count_delete_at_day_endis(1,   0);
    my $week_enabled           = $img->count_delete_at_day_endis(7,   1);
    my $week_disabled          = $img->count_delete_at_day_endis(7,   0);
    my $month_enabled          = $img->count_delete_at_day_endis(30,  1);
    my $month_disabled         = $img->count_delete_at_day_endis(30,  0);
    my $year_enabled           = $img->count_delete_at_day_endis(365, 1);
    my $year_disabled          = $img->count_delete_at_day_endis(365, 0);
    my $year_disabled_in_month = $img->count_delete_at_day_endis(365, 1, time - 335 * 86400);

    $stats->{unlimited} = {
        enabled  => $unlimited_enabled,
        disabled => $unlimited_disabled
    };
    $stats->{day} = {
        enabled  => $day_enabled,
        disabled => $day_disabled
    };
    $stats->{week} = {
        enabled  => $week_enabled,
        disabled => $week_disabled
    };
    $stats->{month} = {
        enabled  => $month_enabled,
        disabled => $month_disabled
    };
    $stats->{year} = {
        enabled  => $year_enabled,
        disabled => $year_disabled
    };

    my $year_disabled_in_month_pct = ($year_enabled != 0) ? " (".sprintf('%.2f', $year_disabled_in_month/$year_enabled)."%)" : '';

    $raw->append_content("\n<tr><td><%= \$raw[4] %></td><td>".$unlimited_enabled."</td><td>".$unlimited_disabled."</td><td>ø</td></tr>\n");
    $raw->append_content("<tr><td><%= \$raw[5] %></td><td>".$day_enabled."</td><td>".$day_disabled."</td><td>".$day_enabled." (100%)</td></tr>\n");
    $raw->append_content("<tr><td><%= \$raw[6] %></td><td>".$week_enabled."</td><td>".$week_disabled."</td><td>".$week_enabled." (100%)</td></tr>\n");
    $raw->append_content("<tr><td><%= \$raw[7] %></td><td>".$month_enabled."</td><td>".$month_disabled."</td><td>".$month_enabled." (100%)</td></tr>\n");
    $raw->append_content("<tr><td><%= \$raw[8] %></td><td>".$year_enabled."</td><td>".$year_disabled."</td><td>".$year_disabled_in_month.$year_disabled_in_month_pct."</td></tr>\n");

    $raw_foot->append_content("\n<tr><td><%= \$raw[9] %></td><td>".($unlimited_enabled + $day_enabled + $week_enabled + $month_enabled + $year_enabled)."</td><td>".($unlimited_disabled + $day_disabled + $week_disabled + $month_disabled + $year_disabled)."</td><td>".($day_enabled + $week_enabled + $month_enabled + $year_disabled_in_month)."</td></tr>\n");

    $dom2 = <<EOF;
% my \@raw = (
%     l('Image delay'),
%     l('Active images'),
%     l('Deleted images'),
%     l('Deleted images in 30 days'),
%     l('no time limit'),
%     l('24 hours'),
%     l('%1 days', 7),
%     l('%1 days', 30),
%     l('1 year'),
%     l('Total')
% );
$dom2
EOF

    my $js = <<EOF;
var enabled_donut = {
  element: 'raw-enabled-holder',
  data: [
    {label: "<%= l('no time limit') %>", value: $unlimited_enabled},
    {label: "<%= l('24 hours') %>", value: $day_enabled},
    {label: "<%= l('%1 days', 7) %>", value: $week_enabled},
    {label: "<%= l('%1 days', 30) %>", value: $month_enabled},
    {label: "<%= l('1 year') %>", value: $year_enabled},
  ],
  colors: [
      '#40b489',
      '#40b9b1',
      '#40a1be',
      '#427dc1',
      '#455ac3',
  ]
};
var disabled_donut = {
  element: 'raw-disabled-holder',
  data: [
    {label: "<%= l('no time limit') %>", value: $unlimited_disabled},
    {label: "<%= l('24 hours') %>", value: $day_disabled},
    {label: "<%= l('%1 days', 7) %>", value: $week_disabled},
    {label: "<%= l('%1 days', 30) %>", value: $month_disabled},
    {label: "<%= l('1 year') %>", value: $year_disabled},
  ],
  colors: [
      '#40b489',
      '#40b9b1',
      '#40a1be',
      '#427dc1',
      '#455ac3',
  ]
};
EOF

    Mojo::File->new('themes/'.$config->{theme}.'/templates/stats.json.ep')->spurt(encode_json($stats));
    Mojo::File->new('themes/'.$config->{theme}.'/templates/data.html.ep')->spurt($dom);
    Mojo::File->new('themes/'.$config->{theme}.'/templates/raw.html.ep')->spurt(encode('UTF-8', $dom2));
    Mojo::File->new('themes/'.$config->{theme}.'/templates/partial/raw.js.ep')->spurt(encode('UTF-8', $js));
}

=encoding utf8

=head1 NAME

Lutim::Command::cron::stats - Stats generator

=head1 SYNOPSIS

  Usage: script/lutim cron stats

=cut

1;
