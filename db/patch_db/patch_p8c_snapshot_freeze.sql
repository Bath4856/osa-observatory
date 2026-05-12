-- ============================================================
-- OSA / ISA — P8C Snapshot Freeze
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS rf;
CREATE SCHEMA IF NOT EXISTS mg;

DROP TABLE IF EXISTS rf.isa_snapshot_freeze_policy CASCADE;

CREATE TABLE rf.isa_snapshot_freeze_policy (
    freeze_policy_code VARCHAR(40) PRIMARY KEY,
    snapshot_type VARCHAR(30) NOT NULL UNIQUE,
    requires_certified BOOLEAN NOT NULL DEFAULT TRUE,
    requires_official BOOLEAN NOT NULL DEFAULT TRUE,
    immutable_after_freeze BOOLEAN NOT NULL DEFAULT TRUE,
    hash_algorithm VARCHAR(20) NOT NULL DEFAULT 'MD5',
    freeze_note TEXT,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO rf.isa_snapshot_freeze_policy (
    freeze_policy_code, snapshot_type, requires_certified, requires_official,
    immutable_after_freeze, hash_algorithm, freeze_note
)
VALUES
('P8C_OFFICIAL_ANNUAL', 'OFFICIAL_ANNUAL', TRUE, TRUE, TRUE, 'MD5',
 'Snapshot officiel annuel gelé après certification.'),
('P8C_PROVISIONAL', 'PROVISIONAL', FALSE, FALSE, FALSE, 'MD5',
 'Snapshot provisoire non immuable.'),
('P8C_INTERNAL_REVIEW', 'INTERNAL_REVIEW', FALSE, FALSE, FALSE, 'MD5',
 'Snapshot interne de revue.')
ON CONFLICT (freeze_policy_code) DO UPDATE SET
    snapshot_type = EXCLUDED.snapshot_type,
    requires_certified = EXCLUDED.requires_certified,
    requires_official = EXCLUDED.requires_official,
    immutable_after_freeze = EXCLUDED.immutable_after_freeze,
    hash_algorithm = EXCLUDED.hash_algorithm,
    freeze_note = EXCLUDED.freeze_note,
    updated_at = NOW();

CREATE TABLE IF NOT EXISTS mg.isa_publication_snapshots (
    snapshot_id BIGSERIAL PRIMARY KEY,
    snapshot_code VARCHAR(80) UNIQUE NOT NULL,
    snapshot_type VARCHAR(30) NOT NULL,
    methodology_version VARCHAR(40),
    publication_cycle VARCHAR(30),
    snapshot_hash TEXT NOT NULL,
    frozen_at TIMESTAMP NOT NULL DEFAULT NOW(),
    frozen_by TEXT DEFAULT CURRENT_USER,
    is_immutable BOOLEAN NOT NULL DEFAULT TRUE,
    notes TEXT
);

DO $$
BEGIN
    RAISE NOTICE 'P8C snapshot freeze policy lignes : %',
        (SELECT COUNT(*) FROM rf.isa_snapshot_freeze_policy);
END $$;

COMMIT;
