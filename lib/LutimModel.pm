package LutimModel;

# Create database
use ORLite {
      file => 'lutim.db',
      unicode => 1,
      create => sub {
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
