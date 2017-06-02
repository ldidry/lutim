-- 1 up
CREATE TABLE IF NOT EXISTS lutim (
    short text PRIMARY KEY,
    path text,
    footprint text,
    enabled integer,
    mediatype text,
    filename text,
    counter integer default 0,
    delete_at_first_view integer,
    delete_at_day integer,
    created_at integer,
    created_by text,
    last_access_at integer,
    mod_token text,
    width integer,
    height integer)'
);
-- 1 down
DROP TABLE lutim;
