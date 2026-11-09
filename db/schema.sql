-- OnRecord schema v0.1
-- Table: members
-- One row per person who has served in Congress.
-- bioguide_id is the master key used by most federal data sources.

CREATE TABLE IF NOT EXISTS members (
    bioguide_id     TEXT PRIMARY KEY,        -- e.g. 'C000127'
    first_name      TEXT NOT NULL,
    last_name       TEXT NOT NULL,
    full_name       TEXT NOT NULL,           -- official display name
    birth_date      TEXT,                    -- ISO format: YYYY-MM-DD
    gender          TEXT,
    party           TEXT,                    -- current or most recent party, as recorded
    state           TEXT,                    -- two-letter code
    district        INTEGER,                 -- NULL for senators; 0 for at-large
    chamber         TEXT CHECK (chamber IN ('house', 'senate')),
    is_current      INTEGER NOT NULL DEFAULT 0 CHECK (is_current IN (0, 1)),
    source_url      TEXT NOT NULL,           -- where this row came from
    retrieved_at    TEXT NOT NULL            -- ISO timestamp of when it was pulled
);

CREATE INDEX IF NOT EXISTS idx_members_state ON members (state);
CREATE INDEX IF NOT EXISTS idx_members_current ON members (is_current);
