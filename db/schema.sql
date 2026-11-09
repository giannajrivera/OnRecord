-- OnRecord schema v0.1
-- Rules for every table:
--   * Every row cites where it came from (source_url) and when it was pulled (retrieved_at).
--   * Money is stored as integer cents.
--   * Dates are ISO text: YYYY-MM-DD (timestamps: YYYY-MM-DDTHH:MM:SSZ).
--   * Source wording is stored as recorded. We do not rewrite official text.
-- Run PRAGMA foreign_keys = ON; on every connection (SQLite does not enforce it by default).

PRAGMA foreign_keys = ON;

-- ============================================================
-- 1. MEMBERS AND TERMS
-- ============================================================

-- One row per person who has served in Congress.
-- bioguide_id is the master key used by most federal data sources.
CREATE TABLE IF NOT EXISTS members (
    bioguide_id     TEXT PRIMARY KEY,        -- e.g. 'C000127'
    first_name      TEXT NOT NULL,
    last_name       TEXT NOT NULL,
    full_name       TEXT NOT NULL,           -- official display name
    birth_date      TEXT,
    gender          TEXT,
    party           TEXT,                    -- current or most recent party, as recorded
    state           TEXT,                    -- two-letter code
    district        INTEGER,                 -- NULL for senators; 0 for at-large
    chamber         TEXT CHECK (chamber IN ('house', 'senate')),
    is_current      INTEGER NOT NULL DEFAULT 0 CHECK (is_current IN (0, 1)),
    source_url      TEXT NOT NULL,
    retrieved_at    TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_members_state ON members (state);
CREATE INDEX IF NOT EXISTS idx_members_current ON members (is_current);

-- One row per term served. Source of truth for position history.
-- The chamber/party/state/district columns in members are a snapshot of the latest term.
CREATE TABLE IF NOT EXISTS terms (
    term_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    bioguide_id     TEXT NOT NULL REFERENCES members (bioguide_id),
    chamber         TEXT NOT NULL CHECK (chamber IN ('house', 'senate')),
    state           TEXT NOT NULL,
    district        INTEGER,                 -- NULL for senators; 0 for at-large
    party           TEXT,                    -- party as recorded for this term
    senate_class    INTEGER CHECK (senate_class IN (1, 2, 3)),
    start_date      TEXT NOT NULL,
    end_date        TEXT,                    -- NULL if ongoing
    source_url      TEXT NOT NULL,
    retrieved_at    TEXT NOT NULL,
    UNIQUE (bioguide_id, chamber, start_date)
);

CREATE INDEX IF NOT EXISTS idx_terms_member ON terms (bioguide_id);
CREATE INDEX IF NOT EXISTS idx_terms_state ON terms (state, chamber);

-- ============================================================
-- 2. COMMITTEES
-- ============================================================

-- One row per committee or subcommittee.
-- committee_id uses thomas_id-style codes from congress-legislators.
CREATE TABLE IF NOT EXISTS committees (
    committee_id         TEXT PRIMARY KEY,
    parent_committee_id  TEXT REFERENCES committees (committee_id),
    name                 TEXT NOT NULL,
    chamber              TEXT NOT NULL CHECK (chamber IN ('house', 'senate', 'joint')),
    congress             INTEGER,
    is_current           INTEGER NOT NULL DEFAULT 0 CHECK (is_current IN (0, 1)),
    url                  TEXT,
    source_url           TEXT NOT NULL,
    retrieved_at         TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_committees_parent ON committees (parent_committee_id);

-- One row per member per committee per Congress, with role as recorded.
CREATE TABLE IF NOT EXISTS committee_memberships (
    membership_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    bioguide_id     TEXT NOT NULL REFERENCES members (bioguide_id),
    committee_id    TEXT NOT NULL REFERENCES committees (committee_id),
    congress        INTEGER NOT NULL,
    role            TEXT,                    -- e.g. 'Chair', 'Ranking Member'; NULL = member
    rank            INTEGER,
    start_date      TEXT,
    end_date        TEXT,
    source_url      TEXT NOT NULL,
    retrieved_at    TEXT NOT NULL,
    UNIQUE (bioguide_id, committee_id, congress)
);

CREATE INDEX IF NOT EXISTS idx_memberships_member ON committee_memberships (bioguide_id);
CREATE INDEX IF NOT EXISTS idx_memberships_committee ON committee_memberships (committee_id);

-- ============================================================
-- 3. BILLS AND SPONSORSHIPS
-- ============================================================

-- bill_id is '{congress}-{type}-{number}', e.g. '119-hr-1'.
CREATE TABLE IF NOT EXISTS bills (
    bill_id             TEXT PRIMARY KEY,
    congress            INTEGER NOT NULL,
    bill_type           TEXT NOT NULL CHECK (bill_type IN
                        ('hr', 's', 'hjres', 'sjres', 'hconres', 'sconres', 'hres', 'sres')),
    bill_number         INTEGER NOT NULL,
    title               TEXT NOT NULL,
    official_title      TEXT,
    introduced_date     TEXT,
    policy_area         TEXT,                -- Congress.gov policy area, as recorded
    latest_action_text  TEXT,                -- as recorded
    latest_action_date  TEXT,
    became_law          INTEGER NOT NULL DEFAULT 0 CHECK (became_law IN (0, 1)),
    public_law_number   TEXT,
    congress_gov_url    TEXT,
    source_url          TEXT NOT NULL,
    retrieved_at        TEXT NOT NULL,
    UNIQUE (congress, bill_type, bill_number)
);

CREATE INDEX IF NOT EXISTS idx_bills_congress ON bills (congress);
CREATE INDEX IF NOT EXISTS idx_bills_policy_area ON bills (policy_area);

-- One row per member per bill. A bill has one sponsor and any number of cosponsors.
CREATE TABLE IF NOT EXISTS sponsorships (
    sponsorship_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    bill_id             TEXT NOT NULL REFERENCES bills (bill_id),
    bioguide_id         TEXT NOT NULL REFERENCES members (bioguide_id),
    role                TEXT NOT NULL CHECK (role IN ('sponsor', 'cosponsor')),
    is_original         INTEGER CHECK (is_original IN (0, 1)),
    sponsored_date      TEXT,
    withdrawn_date      TEXT,
    source_url          TEXT NOT NULL,
    retrieved_at        TEXT NOT NULL,
    UNIQUE (bill_id, bioguide_id)
);

CREATE INDEX IF NOT EXISTS idx_sponsorships_member ON sponsorships (bioguide_id);
CREATE INDEX IF NOT EXISTS idx_sponsorships_bill ON sponsorships (bill_id);

-- ============================================================
-- 4. VOTES
-- ============================================================

-- One row per roll call. vote_id is '{chamber}-{congress}-{session}-{roll}'.
CREATE TABLE IF NOT EXISTS votes (
    vote_id           TEXT PRIMARY KEY,
    chamber           TEXT NOT NULL CHECK (chamber IN ('house', 'senate')),
    congress          INTEGER NOT NULL,
    session           INTEGER NOT NULL CHECK (session IN (1, 2)),
    roll_number       INTEGER NOT NULL,
    vote_date         TEXT NOT NULL,
    question          TEXT,                  -- as recorded
    description       TEXT,                  -- as recorded
    result            TEXT,                  -- as recorded
    bill_id           TEXT REFERENCES bills (bill_id),
    yea_count         INTEGER,
    nay_count         INTEGER,
    present_count     INTEGER,
    not_voting_count  INTEGER,
    source_url        TEXT NOT NULL,
    retrieved_at      TEXT NOT NULL,
    UNIQUE (chamber, congress, session, roll_number)
);

CREATE INDEX IF NOT EXISTS idx_votes_bill ON votes (bill_id);
CREATE INDEX IF NOT EXISTS idx_votes_date ON votes (vote_date);

-- One row per member per roll call.
-- position is normalized; position_raw keeps the exact source value.
CREATE TABLE IF NOT EXISTS member_votes (
    member_vote_id  INTEGER PRIMARY KEY AUTOINCREMENT,
    vote_id         TEXT NOT NULL REFERENCES votes (vote_id),
    bioguide_id     TEXT NOT NULL REFERENCES members (bioguide_id),
    position        TEXT NOT NULL CHECK (position IN
                    ('yea', 'nay', 'present', 'not_voting', 'other')),
    position_raw    TEXT NOT NULL,
    party_at_vote   TEXT,
    state_at_vote   TEXT,
    UNIQUE (vote_id, bioguide_id)
);

CREATE INDEX IF NOT EXISTS idx_member_votes_member ON member_votes (bioguide_id);
CREATE INDEX IF NOT EXISTS idx_member_votes_vote ON member_votes (vote_id);

-- ============================================================
-- 5. CAMPAIGN FINANCE (source: FEC / OpenFEC)
-- ============================================================

-- Links a member to FEC candidate IDs (one member can have several).
CREATE TABLE IF NOT EXISTS member_fec_ids (
    bioguide_id        TEXT NOT NULL REFERENCES members (bioguide_id),
    fec_candidate_id   TEXT NOT NULL,
    source_url         TEXT NOT NULL,
    retrieved_at       TEXT NOT NULL,
    PRIMARY KEY (bioguide_id, fec_candidate_id)
);

-- One row per FEC committee (campaign committees, PACs, party committees).
CREATE TABLE IF NOT EXISTS fec_committees (
    committee_id       TEXT PRIMARY KEY,     -- e.g. 'C00401224'
    name               TEXT NOT NULL,
    committee_type     TEXT,                 -- as recorded by FEC
    designation        TEXT,                 -- as recorded by FEC
    party              TEXT,
    organization_type  TEXT,                 -- as recorded
    connected_org      TEXT,
    source_url         TEXT NOT NULL,
    retrieved_at       TEXT NOT NULL
);

-- Which committees belong to which candidate, per cycle.
CREATE TABLE IF NOT EXISTS candidate_committees (
    fec_candidate_id   TEXT NOT NULL,
    committee_id       TEXT NOT NULL REFERENCES fec_committees (committee_id),
    cycle              INTEGER NOT NULL,
    designation        TEXT,
    source_url         TEXT NOT NULL,
    retrieved_at       TEXT NOT NULL,
    PRIMARY KEY (fec_candidate_id, committee_id, cycle)
);

-- One row per itemized contribution. sub_id is FEC's own unique ID.
-- NOTE: federal law limits use of individual donor info for solicitation or
-- commercial purposes. Check FEC terms before publishing individual names.
CREATE TABLE IF NOT EXISTS fec_contributions (
    sub_id                    TEXT PRIMARY KEY,
    recipient_committee_id    TEXT NOT NULL REFERENCES fec_committees (committee_id),
    contributor_type          TEXT NOT NULL CHECK (contributor_type IN
                              ('individual', 'committee', 'organization', 'other')),
    contributor_name          TEXT,
    contributor_committee_id  TEXT,
    contributor_employer      TEXT,
    contributor_occupation    TEXT,
    contributor_state         TEXT,
    amount_cents              INTEGER NOT NULL,
    receipt_date              TEXT,
    cycle                     INTEGER NOT NULL,
    source_url                TEXT NOT NULL,
    retrieved_at              TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_contrib_recipient ON fec_contributions (recipient_committee_id, cycle);
CREATE INDEX IF NOT EXISTS idx_contrib_donor_committee ON fec_contributions (contributor_committee_id);

-- Summary totals per committee per cycle, as reported by FEC.
CREATE TABLE IF NOT EXISTS fec_cycle_totals (
    committee_id         TEXT NOT NULL REFERENCES fec_committees (committee_id),
    cycle                INTEGER NOT NULL,
    receipts_cents       INTEGER,
    disbursements_cents  INTEGER,
    cash_on_hand_cents   INTEGER,
    coverage_end_date    TEXT,
    source_url           TEXT NOT NULL,
    retrieved_at         TEXT NOT NULL,
    PRIMARY KEY (committee_id, cycle)
);

-- ============================================================
-- 6. TOPICS
-- ============================================================

-- Issue filters users see (e.g. 'Mental Health').
CREATE TABLE IF NOT EXISTS topics (
    topic_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    slug             TEXT NOT NULL UNIQUE,
    name             TEXT NOT NULL,
    description      TEXT,
    parent_topic_id  INTEGER REFERENCES topics (topic_id),
    created_at       TEXT NOT NULL
);

-- Official Congress.gov subject terms, stored as recorded.
CREATE TABLE IF NOT EXISTS bill_subjects (
    bill_id          TEXT NOT NULL REFERENCES bills (bill_id),
    subject          TEXT NOT NULL,
    source_url       TEXT NOT NULL,
    retrieved_at     TEXT NOT NULL,
    PRIMARY KEY (bill_id, subject)
);

CREATE INDEX IF NOT EXISTS idx_bill_subjects_subject ON bill_subjects (subject);

-- Links a bill to an OnRecord topic and records HOW the link was made.
CREATE TABLE IF NOT EXISTS bill_topics (
    bill_id          TEXT NOT NULL REFERENCES bills (bill_id),
    topic_id         INTEGER NOT NULL REFERENCES topics (topic_id),
    method           TEXT NOT NULL CHECK (method IN
                     ('policy_area', 'subject', 'keyword', 'manual')),
    matched_on       TEXT,
    reviewed         INTEGER NOT NULL DEFAULT 0 CHECK (reviewed IN (0, 1)),
    created_at       TEXT NOT NULL,
    PRIMARY KEY (bill_id, topic_id)
);

CREATE INDEX IF NOT EXISTS idx_bill_topics_topic ON bill_topics (topic_id);

-- ============================================================
-- 7. LOBBYING (source: lda.gov API)
-- ============================================================

-- One row per lobbying filing (LD-1 registration or LD-2 quarterly report).
CREATE TABLE IF NOT EXISTS lda_filings (
    filing_uuid       TEXT PRIMARY KEY,
    filing_type       TEXT,                  -- as recorded
    filing_year       INTEGER,
    filing_period     TEXT,                  -- as recorded
    registrant_id     TEXT,
    registrant_name   TEXT NOT NULL,         -- the lobbying firm
    client_id         TEXT,
    client_name       TEXT NOT NULL,         -- who paid
    income_cents      INTEGER,
    expenses_cents    INTEGER,
    posted_date       TEXT,
    document_url      TEXT,
    source_url        TEXT NOT NULL,
    retrieved_at      TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_lda_filings_client ON lda_filings (client_name);
CREATE INDEX IF NOT EXISTS idx_lda_filings_year ON lda_filings (filing_year);

-- Issue areas listed on a filing.
CREATE TABLE IF NOT EXISTS lda_activities (
    activity_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    filing_uuid       TEXT NOT NULL REFERENCES lda_filings (filing_uuid),
    issue_code        TEXT,                  -- as recorded
    description       TEXT,                  -- as recorded
    source_url        TEXT NOT NULL,
    retrieved_at      TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_lda_activities_filing ON lda_activities (filing_uuid);

-- Filings that mention a specific bill. matched_on records the exact text matched.
CREATE TABLE IF NOT EXISTS lda_bill_mentions (
    filing_uuid       TEXT NOT NULL REFERENCES lda_filings (filing_uuid),
    bill_id           TEXT NOT NULL REFERENCES bills (bill_id),
    matched_on        TEXT NOT NULL,
    method            TEXT NOT NULL CHECK (method IN ('script', 'manual')),
    reviewed          INTEGER NOT NULL DEFAULT 0 CHECK (reviewed IN (0, 1)),
    PRIMARY KEY (filing_uuid, bill_id)
);

-- Lobbyist political contributions (LD-203 reports).
CREATE TABLE IF NOT EXISTS lda_contributions (
    contribution_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    filing_uuid        TEXT NOT NULL,
    contributor_name   TEXT,
    payee_name         TEXT,
    honoree_name       TEXT,
    bioguide_id        TEXT REFERENCES members (bioguide_id),  -- only if matched
    amount_cents       INTEGER,
    contribution_date  TEXT,
    contribution_type  TEXT,                 -- as recorded
    source_url         TEXT NOT NULL,
    retrieved_at       TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_lda_contrib_member ON lda_contributions (bioguide_id);

-- ============================================================
-- 8. FINANCIAL DISCLOSURES (House Clerk and Senate eFD)
-- ============================================================

-- One row per filed report.
CREATE TABLE IF NOT EXISTS disclosure_reports (
    report_id         TEXT PRIMARY KEY,      -- source's own ID or document name
    bioguide_id       TEXT REFERENCES members (bioguide_id),  -- NULL if not yet matched
    filer_name        TEXT NOT NULL,
    chamber           TEXT CHECK (chamber IN ('house', 'senate')),
    report_type       TEXT,                  -- as recorded: annual, periodic transaction, etc.
    filing_year       INTEGER,
    filing_date       TEXT,
    document_url      TEXT,
    source_url        TEXT NOT NULL,
    retrieved_at      TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_disclosure_member ON disclosure_reports (bioguide_id);

-- Transactions listed on periodic transaction reports.
-- Amounts are ranges in the source, so we store a minimum and a maximum.
-- verified = 1 only after a human checked the row against the original document.
CREATE TABLE IF NOT EXISTS stock_transactions (
    transaction_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    report_id          TEXT NOT NULL REFERENCES disclosure_reports (report_id),
    bioguide_id        TEXT REFERENCES members (bioguide_id),
    owner              TEXT,                 -- as recorded: self, spouse, dependent, joint
    asset_name         TEXT NOT NULL,
    ticker             TEXT,
    transaction_type   TEXT,                 -- as recorded: purchase, sale, exchange
    transaction_date   TEXT,
    notification_date  TEXT,
    amount_min_cents   INTEGER,
    amount_max_cents   INTEGER,
    parsed_by          TEXT NOT NULL CHECK (parsed_by IN ('script', 'manual')),
    verified           INTEGER NOT NULL DEFAULT 0 CHECK (verified IN (0, 1)),
    source_url         TEXT NOT NULL,
    retrieved_at       TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_stock_tx_member ON stock_transactions (bioguide_id);
CREATE INDEX IF NOT EXISTS idx_stock_tx_ticker ON stock_transactions (ticker);

-- ============================================================
-- 9. WORDS: SOURCES, STATEMENTS, AND FLAGGED CONFLICTS
-- ============================================================

-- Every quote must point to a source document.
CREATE TABLE IF NOT EXISTS sources (
    source_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    url             TEXT NOT NULL UNIQUE,
    source_type     TEXT NOT NULL CHECK (source_type IN
                    ('transcript', 'floor_speech', 'hearing', 'press_release',
                     'campaign_site', 'interview', 'social_media', 'op_ed', 'other')),
    title           TEXT,
    publisher       TEXT,
    published_date  TEXT,
    archive_url     TEXT,                    -- archived copy, in case the page changes
    content_hash    TEXT,
    retrieved_at    TEXT NOT NULL
);

-- A documented public statement of position.
-- quote is the exact wording. stance_summary is a short neutral description.
-- Anything extracted by software starts as 'unverified' until a human reviews it.
CREATE TABLE IF NOT EXISTS statements (
    statement_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    bioguide_id        TEXT NOT NULL REFERENCES members (bioguide_id),
    topic_id           INTEGER REFERENCES topics (topic_id),
    source_id          INTEGER NOT NULL REFERENCES sources (source_id),
    quote              TEXT NOT NULL,
    stance_summary     TEXT,
    statement_date     TEXT NOT NULL,
    context_note       TEXT,
    extraction_method  TEXT NOT NULL CHECK (extraction_method IN ('manual', 'ai_extracted')),
    status             TEXT NOT NULL DEFAULT 'unverified' CHECK (status IN
                       ('unverified', 'verified', 'disputed', 'retracted')),
    reviewed_by        TEXT,
    reviewed_at        TEXT,
    created_at         TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_statements_member ON statements (bioguide_id);
CREATE INDEX IF NOT EXISTS idx_statements_topic ON statements (topic_id);
CREATE INDEX IF NOT EXISTS idx_statements_status ON statements (status);

-- A flagged conflict between a stated position and a later action.
-- Both sides are always shown together with sources.
-- A flag needs at least one later action: a vote or a sponsorship.
-- reasoning must say, in plain words, why the two directly conflict.
-- Only status = 'confirmed' flags are shown publicly as conflicts.
CREATE TABLE IF NOT EXISTS conflict_flags (
    flag_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    statement_id     INTEGER NOT NULL REFERENCES statements (statement_id),
    member_vote_id   INTEGER REFERENCES member_votes (member_vote_id),
    sponsorship_id   INTEGER REFERENCES sponsorships (sponsorship_id),
    status           TEXT NOT NULL DEFAULT 'proposed' CHECK (status IN
                     ('proposed', 'confirmed', 'unclear', 'rejected')),
    reasoning        TEXT NOT NULL,
    proposed_by      TEXT NOT NULL CHECK (proposed_by IN ('script', 'manual')),
    reviewed_by      TEXT,
    reviewed_at      TEXT,
    created_at       TEXT NOT NULL,
    CHECK (member_vote_id IS NOT NULL OR sponsorship_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_conflict_statement ON conflict_flags (statement_id);
CREATE INDEX IF NOT EXISTS idx_conflict_status ON conflict_flags (status);

-- ============================================================
-- 10. QUALITY: CORRECTIONS AND SYNC LOG
-- ============================================================

-- Public error reports. Accepted fixes are recorded here as a changelog.
CREATE TABLE IF NOT EXISTS corrections (
    correction_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    target_table     TEXT NOT NULL,
    target_key       TEXT NOT NULL,          -- primary key value of the row in question
    field_name       TEXT,
    report_text      TEXT NOT NULL,
    evidence_url     TEXT,
    reporter_contact TEXT,                   -- optional
    status           TEXT NOT NULL DEFAULT 'open' CHECK (status IN
                     ('open', 'accepted', 'rejected')),
    resolution_note  TEXT,
    created_at       TEXT NOT NULL,
    resolved_at      TEXT
);

CREATE INDEX IF NOT EXISTS idx_corrections_status ON corrections (status);
CREATE INDEX IF NOT EXISTS idx_corrections_target ON corrections (target_table, target_key);

-- One row per data sync, so every page can show a real "last updated" date.
CREATE TABLE IF NOT EXISTS sync_runs (
    run_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    source_name    TEXT NOT NULL,            -- e.g. 'congress.gov members'
    started_at     TEXT NOT NULL,
    finished_at    TEXT,
    status         TEXT NOT NULL CHECK (status IN ('running', 'success', 'failed')),
    rows_written   INTEGER,
    notes          TEXT
);

CREATE INDEX IF NOT EXISTS idx_sync_runs_source ON sync_runs (source_name, started_at);
