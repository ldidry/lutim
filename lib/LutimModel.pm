package LutimModel;
use Mojolicious;
use FindBin qw($Bin);
use File::Spec qw(catfile);

BEGIN {
    my $m = Mojolicious->new;
    our $config = $m->plugin('Config' =>
        {
            file    => File::Spec->catfile($Bin, '..' ,'lutim.conf'),
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
