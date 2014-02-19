package Mojolicious::Command::cron;
use Mojo::Base 'Mojolicious::Commands';

has description => 'Execute tasks.';
has hint        => <<EOF;

See 'script/lutim cron help TASK' for more information on a specific task.
EOF
has message    => sub { shift->extract_usage . "\nCron tasks:\n" };
has namespaces => sub { ['Mojolicious::Command::cron'] };

sub help { shift->run(@_) }

1;

=encoding utf8

=head1 NAME

Mojolicious::Command::cron - Cron commands

=head1 SYNOPSIS

  Usage: script/lutim cron TASK [OPTIONS]

=cut
