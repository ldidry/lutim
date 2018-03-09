-- 1 up
CREATE TABLE IF NOT EXISTS lutim (
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
    height                INTEGER
);
-- 1 down
DROP TABLE lutim;
-- 2 up
ALTER TABLE lutim ADD COLUMN iv TEXT;
-- 2 down
