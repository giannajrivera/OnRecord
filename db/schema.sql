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

-- Table: terms
-- One row per term served. A member can have many terms.
-- This is the source of truth for position history. The chamber, party,
-- state, and district columns in members are just a snapshot of the latest term.

CREATE TABLE IF NOT EXISTS terms (
    term_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    bioguide_id     TEXT NOT NULL REFERENCES members (bioguide_id),
    chamber         TEXT NOT NULL CHECK (chamber IN ('house', 'senate')),
    state           TEXT NOT NULL,           -- two-letter code
    district        INTEGER,                 -- NULL for senators; 0 for at-large
    party           TEXT,                    -- party as recorded for this term
    senate_class    INTEGER CHECK (senate_class IN (1, 2, 3)),  -- senators only
    start_date      TEXT NOT NULL,           -- ISO format: YYYY-MM-DD
    end_date        TEXT,                    -- NULL if the term is ongoing
    source_url      TEXT NOT NULL,
    retrieved_at    TEXT NOT NULL,
    UNIQUE (bioguide_id, chamber, start_date)
);

CREATE INDEX IF NOT EXISTS idx_terms_member ON terms (bioguide_id);
CREATE INDEX IF NOT EXISTS idx_terms_state ON terms (state, chamber);

-- Table: committees
-- One row per committee or subcommittee.
-- Subcommittees point to their parent through parent_committee_id.
-- committee_id uses the thomas_id style codes from congress-legislators
-- (for example 'HSAG' for a committee, 'HSAG03' for a subcommittee).

CREATE TABLE IF NOT EXISTS committees (
    committee_id         TEXT PRIMARY KEY,
    parent_committee_id  TEXT REFERENCES committees (committee_id),  -- NULL for full committees
    name                 TEXT NOT NULL,
    chamber              TEXT NOT NULL CHECK (chamber IN ('house', 'senate', 'joint')),
    congress             INTEGER,            -- e.g. 119; NULL if not tied to one Congress
    is_current           INTEGER NOT NULL DEFAULT 0 CHECK (is_current IN (0, 1)),
    url                  TEXT,               -- committee's official website
    source_url           TEXT NOT NULL,
    retrieved_at         TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_committees_parent ON committees (parent_committee_id);

-- Table: committee_memberships
-- One row per member per committee per Congress, with their role.
-- Roles are stored as recorded in the source (for example 'Chair',
-- 'Ranking Member', 'Vice Chair'). NULL means a regular member.

CREATE TABLE IF NOT EXISTS committee_memberships (
    membership_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    bioguide_id     TEXT NOT NULL REFERENCES members (bioguide_id),
    committee_id    TEXT NOT NULL REFERENCES committees (committee_id),
    congress        INTEGER NOT NULL,        -- e.g. 119
    role            TEXT,
    rank            INTEGER,                 -- seniority order in the source, if given
    start_date      TEXT,                    -- ISO format; NULL if not provided
    end_date        TEXT,                    -- NULL if still serving
    source_url      TEXT NOT NULL,
    retrieved_at    TEXT NOT NULL,
    UNIQUE (bioguide_id, committee_id, congress)
);

CREATE INDEX IF NOT EXISTS idx_memberships_member ON committee_memberships (bioguide_id);
CREATE INDEX IF NOT EXISTS idx_memberships_committee ON committee_memberships (committee_id);
