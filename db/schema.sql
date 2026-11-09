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

-- Table: bills
-- One row per bill or resolution.
-- bill_id is built as '{congress}-{type}-{number}', for example '119-hr-1'.
-- Type codes are lowercase, matching the Congress.gov API:
-- hr, s, hjres, sjres, hconres, sconres, hres, sres.

CREATE TABLE IF NOT EXISTS bills (
    bill_id             TEXT PRIMARY KEY,
    congress            INTEGER NOT NULL,        -- e.g. 119
    bill_type           TEXT NOT NULL CHECK (bill_type IN
                        ('hr', 's', 'hjres', 'sjres', 'hconres', 'sconres', 'hres', 'sres')),
    bill_number         INTEGER NOT NULL,
    title               TEXT NOT NULL,           -- short title if one exists, else official title
    official_title      TEXT,
    introduced_date     TEXT,                    -- ISO format: YYYY-MM-DD
    policy_area         TEXT,                    -- Congress.gov policy area, as recorded
    latest_action_text  TEXT,                    -- as recorded; we do not rewrite it
    latest_action_date  TEXT,
    became_law          INTEGER NOT NULL DEFAULT 0 CHECK (became_law IN (0, 1)),
    public_law_number   TEXT,                    -- e.g. '119-12', NULL if not enacted
    congress_gov_url    TEXT,
    source_url          TEXT NOT NULL,
    retrieved_at        TEXT NOT NULL,
    UNIQUE (congress, bill_type, bill_number)
);

CREATE INDEX IF NOT EXISTS idx_bills_congress ON bills (congress);
CREATE INDEX IF NOT EXISTS idx_bills_policy_area ON bills (policy_area);

-- Table: sponsorships
-- One row per member per bill, marking sponsor or cosponsor.
-- A bill has exactly one sponsor and any number of cosponsors.

CREATE TABLE IF NOT EXISTS sponsorships (
    sponsorship_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    bill_id             TEXT NOT NULL REFERENCES bills (bill_id),
    bioguide_id         TEXT NOT NULL REFERENCES members (bioguide_id),
    role                TEXT NOT NULL CHECK (role IN ('sponsor', 'cosponsor')),
    is_original         INTEGER CHECK (is_original IN (0, 1)),  -- original cosponsor?
    sponsored_date      TEXT,                    -- date they signed on
    withdrawn_date      TEXT,                    -- NULL if never withdrawn
    source_url          TEXT NOT NULL,
    retrieved_at        TEXT NOT NULL,
    UNIQUE (bill_id, bioguide_id)
);

CREATE INDEX IF NOT EXISTS idx_sponsorships_member ON sponsorships (bioguide_id);
CREATE INDEX IF NOT EXISTS idx_sponsorships_bill ON sponsorships (bill_id);

-- Table: votes
-- One row per roll call vote.
-- vote_id is built as '{chamber}-{congress}-{session}-{roll}',
-- for example 'house-119-1-123'.
-- Sources: House Clerk and Senate roll-call XML.

CREATE TABLE IF NOT EXISTS votes (
    vote_id         TEXT PRIMARY KEY,
    chamber         TEXT NOT NULL CHECK (chamber IN ('house', 'senate')),
    congress        INTEGER NOT NULL,
    session         INTEGER NOT NULL CHECK (session IN (1, 2)),
    roll_number     INTEGER NOT NULL,
    vote_date       TEXT NOT NULL,           -- ISO format: YYYY-MM-DD
    question        TEXT,                    -- as recorded, e.g. 'On Passage'
    description     TEXT,                    -- as recorded; we do not rewrite it
    result          TEXT,                    -- as recorded, e.g. 'Passed'
    bill_id         TEXT REFERENCES bills (bill_id),  -- NULL if not about a bill
    yea_count       INTEGER,
    nay_count       INTEGER,
    present_count   INTEGER,
    not_voting_count INTEGER,
    source_url      TEXT NOT NULL,
    retrieved_at    TEXT NOT NULL,
    UNIQUE (chamber, congress, session, roll_number)
);

CREATE INDEX IF NOT EXISTS idx_votes_bill ON votes (bill_id);
CREATE INDEX IF NOT EXISTS idx_votes_date ON votes (vote_date);

-- Table: member_votes
-- One row per member per roll call.
-- position is normalized; position_raw keeps the exact value from the source.
-- 'other' covers votes that are not yea/nay/present/not voting,
-- such as a candidate's name in a Speaker election.

CREATE TABLE IF NOT EXISTS member_votes (
    member_vote_id  INTEGER PRIMARY KEY AUTOINCREMENT,
    vote_id         TEXT NOT NULL REFERENCES votes (vote_id),
    bioguide_id     TEXT NOT NULL REFERENCES members (bioguide_id),
    position        TEXT NOT NULL CHECK (position IN
                    ('yea', 'nay', 'present', 'not_voting', 'other')),
    position_raw    TEXT NOT NULL,
    party_at_vote   TEXT,                    -- party as listed on that vote
    state_at_vote   TEXT,
    UNIQUE (vote_id, bioguide_id)
);

CREATE INDEX IF NOT EXISTS idx_member_votes_member ON member_votes (bioguide_id);
CREATE INDEX IF NOT EXISTS idx_member_votes_vote ON member_votes (vote_id);
