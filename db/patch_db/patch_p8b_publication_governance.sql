-- ============================================================
-- OSA / ISA — P8B Publication Governance
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS rf;
CREATE SCHEMA IF NOT EXISTS ma;
CREATE SCHEMA IF NOT EXISTS mg;

DROP TABLE IF EXISTS rf.isa_publication_workflow_policy CASCADE;

CREATE TABLE rf.isa_publication_workflow_policy (
    workflow_status VARCHAR(30) PRIMARY KEY,
    workflow_order INTEGER NOT NULL,
    is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    requires_certification BOOLEAN NOT NULL DEFAULT TRUE,
    workflow_note TEXT,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO rf.isa_publication_workflow_policy (
    workflow_status, workflow_order, is_terminal, is_public, requires_certification, workflow_note
)
VALUES
('DRAFT', 10, FALSE, FALSE, FALSE, 'Préparation interne.'),
('INTERNAL_REVIEW', 20, FALSE, FALSE, TRUE, 'Revue interne OSA.'),
('EXPERT_REVIEW', 30, FALSE, FALSE, TRUE, 'Revue experts / pairs.'),
('CERTIFIED', 40, FALSE, FALSE, TRUE, 'Certifié mais pas encore publié.'),
('PUBLISHED', 50, FALSE, TRUE, TRUE, 'Publication officielle ou provisoire.'),
('ARCHIVED', 80, TRUE, FALSE, TRUE, 'Archive historique.'),
('SUPERSEDED', 90, TRUE, FALSE, TRUE, 'Remplacé par un snapshot plus récent.')
ON CONFLICT (workflow_status) DO UPDATE SET
    workflow_order = EXCLUDED.workflow_order,
    is_terminal = EXCLUDED.is_terminal,
    is_public = EXCLUDED.is_public,
    requires_certification = EXCLUDED.requires_certification,
    workflow_note = EXCLUDED.workflow_note,
    updated_at = NOW();

DO $$
BEGIN
    RAISE NOTICE 'P8B publication workflow lignes : %',
        (SELECT COUNT(*) FROM rf.isa_publication_workflow_policy);
END $$;

COMMIT;
