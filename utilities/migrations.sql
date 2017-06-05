-- 1 up
CREATE TABLE IF NOT EXISTS lutim (
    short text PRIMARY KEY,
    path text default null,
    footprint text default null,
    enabled integer,
    mediatype text default null,
    filename text default null,
    counter integer default 0,
    delete_at_first_view integer default null,
    delete_at_day integer default null,
    created_at integer default null,
    created_by text default null,
    last_access_at integer default null,
    mod_token text default null,
    width integer default null,
    height integer default null
);
-- 1 down
DROP TABLE lutim;
