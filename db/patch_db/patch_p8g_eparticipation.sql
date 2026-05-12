-- ============================================================
-- OSA / ISA — P8G E-participation
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS rf;
CREATE SCHEMA IF NOT EXISTS mg;

DROP TABLE IF EXISTS rf.isa_eparticipation_policy CASCADE;

CREATE TABLE rf.isa_eparticipation_policy (
    topic_type VARCHAR(80) PRIMARY KEY,
    queue_priority INTEGER NOT NULL DEFAULT 50,
    requires_moderation BOOLEAN NOT NULL DEFAULT TRUE,
    allows_public_comment BOOLEAN NOT NULL DEFAULT TRUE,
    allows_evidence_upload BOOLEAN NOT NULL DEFAULT FALSE,
    policy_note TEXT,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO rf.isa_eparticipation_policy (
    topic_type, queue_priority, requires_moderation, allows_public_comment,
    allows_evidence_upload, policy_note
)
VALUES
('RISK_EVIDENCE_AND_EXPERT_REVIEW', 10, TRUE, TRUE, TRUE, 'Revue experte et preuves sur risques.'),
('PUBLIC_COMMENTS_AND_DIAGNOSTIC_REVIEW', 20, TRUE, TRUE, TRUE, 'Commentaires publics et revue diagnostic.'),
('CO_DESIGN_AND_INVESTOR_FEEDBACK', 30, TRUE, TRUE, FALSE, 'Co-design et retours investisseurs.'),
('BENCHMARK_AND_REPLICATION_FEEDBACK', 40, TRUE, TRUE, FALSE, 'Benchmark et réplicabilité.'),
('GENERAL_OBSERVATORY_FEEDBACK', 50, TRUE, TRUE, FALSE, 'Feedback général observatoire.')
ON CONFLICT (topic_type) DO UPDATE SET
    queue_priority = EXCLUDED.queue_priority,
    requires_moderation = EXCLUDED.requires_moderation,
    allows_public_comment = EXCLUDED.allows_public_comment,
    allows_evidence_upload = EXCLUDED.allows_evidence_upload,
    policy_note = EXCLUDED.policy_note,
    updated_at = NOW();

CREATE TABLE IF NOT EXISTS mg.isa_eparticipation_feedback (
    feedback_id BIGSERIAL PRIMARY KEY,
    country_iso3 CHAR(3),
    year SMALLINT,
    pillar_code VARCHAR(10),
    topic_type VARCHAR(80),
    submitter_type VARCHAR(40),
    comment_text TEXT,
    evidence_url TEXT,
    moderation_status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

DO $$
BEGIN
    RAISE NOTICE 'P8G eparticipation policy lignes : %',
        (SELECT COUNT(*) FROM rf.isa_eparticipation_policy);
END $$;

COMMIT;
