-- ============================================================
-- OSA / ISA — P8A Certification Engine
-- Idempotent professional v5
-- Purpose: certification policy only. Drop/recreate RF policy to avoid
-- schema drift from previous failed P8 attempts.
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS rf;
CREATE SCHEMA IF NOT EXISTS ma;
CREATE SCHEMA IF NOT EXISTS mg;

DROP TABLE IF EXISTS rf.isa_certification_policy CASCADE;

CREATE TABLE rf.isa_certification_policy (
    policy_code VARCHAR(40) PRIMARY KEY,
    certification_status VARCHAR(30) NOT NULL UNIQUE,
    min_data_completeness NUMERIC(5,3) NOT NULL DEFAULT 0.850,
    min_confidence_proxy NUMERIC(5,3) NOT NULL DEFAULT 0.550,
    min_pillars_observed INTEGER NOT NULL DEFAULT 8,
    requires_official_publication BOOLEAN NOT NULL DEFAULT FALSE,
    allows_provisional_publication BOOLEAN NOT NULL DEFAULT FALSE,
    allows_open_data BOOLEAN NOT NULL DEFAULT FALSE,
    allows_premium_delivery BOOLEAN NOT NULL DEFAULT FALSE,
    freeze_eligible BOOLEAN NOT NULL DEFAULT FALSE,
    priority_order INTEGER NOT NULL DEFAULT 99,
    certification_note TEXT,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO rf.isa_certification_policy (
    policy_code,
    certification_status,
    min_data_completeness,
    min_confidence_proxy,
    min_pillars_observed,
    requires_official_publication,
    allows_provisional_publication,
    allows_open_data,
    allows_premium_delivery,
    freeze_eligible,
    priority_order,
    certification_note
)
VALUES
('P8A_CERTIFIED', 'CERTIFIED', 0.850, 0.550, 8, TRUE,  FALSE, TRUE,  TRUE,  TRUE,  10,
 'Score officialisable : couverture, cohérence et statut consolidé suffisants.'),
('P8A_PROVISIONAL', 'PROVISIONAL', 0.650, 0.450, 7, FALSE, TRUE,  TRUE,  FALSE, FALSE, 20,
 'Score provisoire : données incomplètes ou en cours de consolidation.'),
('P8A_REVIEW_REQUIRED', 'REVIEW_REQUIRED', 0.450, 0.300, 5, FALSE, FALSE, FALSE, FALSE, FALSE, 30,
 'Revue requise avant usage institutionnel.'),
('P8A_REJECTED', 'REJECTED', 0.000, 0.000, 0, FALSE, FALSE, FALSE, FALSE, FALSE, 90,
 'Score rejeté pour publication : couverture ou cohérence insuffisante.')
ON CONFLICT (policy_code) DO UPDATE SET
    certification_status = EXCLUDED.certification_status,
    min_data_completeness = EXCLUDED.min_data_completeness,
    min_confidence_proxy = EXCLUDED.min_confidence_proxy,
    min_pillars_observed = EXCLUDED.min_pillars_observed,
    requires_official_publication = EXCLUDED.requires_official_publication,
    allows_provisional_publication = EXCLUDED.allows_provisional_publication,
    allows_open_data = EXCLUDED.allows_open_data,
    allows_premium_delivery = EXCLUDED.allows_premium_delivery,
    freeze_eligible = EXCLUDED.freeze_eligible,
    priority_order = EXCLUDED.priority_order,
    certification_note = EXCLUDED.certification_note,
    updated_at = NOW();

DO $$
BEGIN
    RAISE NOTICE 'P8A certification policy lignes : %',
        (SELECT COUNT(*) FROM rf.isa_certification_policy);
END $$;

COMMIT;
