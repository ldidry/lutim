# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lutim::DB::SQLite;
use Mojolicious;
use Mojo::File;
use FindBin qw($Bin);

BEGIN {
    my $m = Mojolicious->new;
    our $config = $m->plugin('Config' =>
        {
            file    => Mojo::File->new($Bin, '..' ,'lutim.conf')->to_abs->to_string,
            default => {
                db_path => 'lutim.db'
            }
        }
    );
}

# Create database
use ORLite {
      file    => $config->{db_path},
      unicode => 1,
      create  => sub {
          my $dbh = shift;
          $dbh->do(
              'CREATE TABLE lutim (
               short                 TEXT PRIMARY KEY,
               path                  TEXT,
               footprint             TEXT,
               enabled               INTEGER,
               mediatype             TEXT,
               filename              TEXT,
               counter               INTEGER,
               delete_at_first_view  INTEGER,
               delete_at_day         INTEGER,
               created_at            INTEGER,
               created_by            TEXT,
               last_access_at        INTEGER,
               mod_token             TEXT,
               width                 INTEGER,
               height                INTEGER)'
          );
          return 1;
     }
};

1;
