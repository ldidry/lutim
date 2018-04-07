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
-- 2 up
ALTER TABLE lutim ADD COLUMN iv text;
-- 2 down
ALTER TABLE lutim DROP COLUMN iv;
-- 3 up
CREATE INDEX IF NOT EXISTS empty_short_idx ON lutim (short) WHERE path IS NULL;
-- 3 down
DROP INDEX empty_short_idx;
