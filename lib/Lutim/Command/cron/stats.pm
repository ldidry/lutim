package Lutim::Command::cron::stats;
use Mojo::Base 'Mojolicious::Command';
use LutimModel;
use Mojo::DOM;
use Mojo::Util qw(slurp spurt encode);
use DateTime;
use FindBin qw($Bin);
use File::Spec qw(catfile);

has description => 'Generate statistics about Lutim.';
has usage => sub { shift->extract_usage };

sub run {
    my $c = shift;

    my $config = $c->app->plugin('Config', {
        file    => File::Spec->catfile($Bin, '..' ,'lutim.conf'),
        theme   => 'default',
        default => {
            stats_day_num => 365
        }
    });

    my $template = 'themes/'.$config->{theme}.'/templates/data.html.ep.template';
    unless (-e $template) {
        $config->{theme} = 'default';
        $template = 'themes/'.$config->{theme}.'/templates/data.html.ep.template';
    }
    my $text     = slurp($template);
    my $dom      = Mojo::DOM->new($text);
    my $thead_tr = $dom->at('table thead tr');
    my $tbody_tr = $dom->at('table tbody tr');
    my $tbody_t2 = $tbody_tr->next;

    my $separation = time() - $config->{stats_day_num} * 86400;

    my %data;
    for my $img (LutimModel::Lutim->select('WHERE path IS NOT NULL AND created_at >= ?', $separation)) {
        my $time                 = DateTime->from_epoch(epoch => $img->created_at);
        my ($year, $month, $day) = ($time->year(), $time->month(), $time->day());

        if (defined($data{$year}->{$month}->{$day})) {
            $data{$year}->{$month}->{$day} += 1;
        } else {
            $data{$year}->{$month}->{$day} = 1;
        }
    }

    my $total = LutimModel::Lutim->count('WHERE path IS NOT NULL AND created_at < ?', $separation);
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

    # Raw datas
    my $template2 = 'themes/'.$config->{theme}.'/templates/raw.html.ep.template';
    unless (-e $template2) {
        $config->{theme} = 'default';
        $template = 'themes/'.$config->{theme}.'/templates/raw.html.ep.template';
    }
    my $text2    = slurp($template2);
    my $dom2     = Mojo::DOM->new($text2);
    my $raw      = $dom2->at('table tbody');
    my $raw_foot = $dom2->at('table tfoot');
    my $unlimited_enabled      = LutimModel::Lutim->count('WHERE path IS NOT NULL AND delete_at_day = 0   AND enabled = 1');
    my $unlimited_disabled     = LutimModel::Lutim->count('WHERE path IS NOT NULL AND delete_at_day = 0   AND enabled = 0');
    my $day_enabled            = LutimModel::Lutim->count('WHERE path IS NOT NULL AND delete_at_day = 1   AND enabled = 1');
    my $day_disabled           = LutimModel::Lutim->count('WHERE path IS NOT NULL AND delete_at_day = 1   AND enabled = 0');
    my $week_enabled           = LutimModel::Lutim->count('WHERE path IS NOT NULL AND delete_at_day = 7   AND enabled = 1');
    my $week_disabled          = LutimModel::Lutim->count('WHERE path IS NOT NULL AND delete_at_day = 7   AND enabled = 0');
    my $month_enabled          = LutimModel::Lutim->count('WHERE path IS NOT NULL AND delete_at_day = 30  AND enabled = 1');
    my $month_disabled         = LutimModel::Lutim->count('WHERE path IS NOT NULL AND delete_at_day = 30  AND enabled = 0');
    my $year_enabled           = LutimModel::Lutim->count('WHERE path IS NOT NULL AND delete_at_day = 365 AND enabled = 1');
    my $year_disabled          = LutimModel::Lutim->count('WHERE path IS NOT NULL AND delete_at_day = 365 AND enabled = 0');
    my $year_disabled_in_month = LutimModel::Lutim->count('WHERE path IS NOT NULL AND delete_at_day = 365 AND enabled = 0 AND created_at < ?', time - 30 * 86400);

    $raw->append_content("\n<tr><td><%= \$raw[4] %></td><td>".$unlimited_enabled."</td><td>".$unlimited_disabled."</td><td>ø</td></tr>\n");
    $raw->append_content("<tr><td><%= \$raw[5] %></td><td>".$day_enabled."</td><td>".$day_disabled."</td><td>".$day_enabled." (100%)</td></tr>\n");
    $raw->append_content("<tr><td><%= \$raw[6] %></td><td>".$week_enabled."</td><td>".$week_disabled."</td><td>".$week_enabled." (100%)</td></tr>\n");
    $raw->append_content("<tr><td><%= \$raw[7] %></td><td>".$month_enabled."</td><td>".$month_disabled."</td><td>".$month_enabled." (100%)</td></tr>\n");
    $raw->append_content("<tr><td><%= \$raw[8] %></td><td>".$year_enabled."</td><td>".$year_disabled."</td><td>".$year_disabled_in_month." (".sprintf('%.2f', $year_disabled_in_month/$year_enabled)."%)</td></tr>\n");

    $raw_foot->append_content("\n<tr><td><%= \$raw[9] %></td><td>".($unlimited_enabled + $day_enabled + $week_enabled + $month_enabled + $year_enabled)."</td><td>".($unlimited_disabled + $day_disabled + $week_disabled + $month_disabled + $year_disabled)."</td><td>".($day_enabled + $week_enabled + $month_enabled + $year_disabled_in_month)."</td></tr>\n");

    $dom2 = <<EOF;
% my \@raw = (
%     l('Image delay'),
%     l('Enabled'),
%     l('Disabled'),
%     l('Disabled in 30 days'),
%     l('no time limit'),
%     l('24 hours'),
%     l('%1 days', 7),
%     l('%1 days', 30),
%     l('1 year'),
%     l('Total')
% );
<script>
Morris.Donut({
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
});
Morris.Donut({
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
});
</script>
$dom2
EOF

    spurt $dom, 'themes/'.$config->{theme}.'/templates/data.html.ep';
    spurt encode('UTF-8', $dom2), 'themes/'.$config->{theme}.'/templates/raw.html.ep';
}

=encoding utf8

=head1 NAME

Lutim::Command::cron::stats - Stats generator

=head1 SYNOPSIS

  Usage: script/lutim cron stats

=cut

1;
