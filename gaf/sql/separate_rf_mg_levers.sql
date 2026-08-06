-- ============================================================
-- Separation rf.strategic_levers (referentiel) / mg.lever_evidence (occurrence)
-- 5 aout 2026
-- ============================================================
-- Decision de Theo : coherent avec toute l'architecture rf/mg du projet
-- -- rf contient la connaissance normative (definition du levier, nom,
-- description, domaine, famille, statut d'approbation), mg contient la
-- connaissance produite par l'execution des moteurs de genie scientifique
-- (pourquoi ce levier a ete retenu, pour quelle vision, a partir de
-- quelles analyses, avec quel niveau de pertinence).
--
-- mg.strategic_levers (catalogue partage, Sprint OIM Lot 1/2) devient
-- rf.strategic_levers, enrichi de domain_pillar_code/family/
-- approval_status.
--
-- mg.root_cause_levers (analysis_id, lever_code, relevance_weight)
-- devient mg.lever_evidence (id, lever_code, analysis_id, evidence_type,
-- relevance_weight, comment) -- evidence_type = la methode source
-- (SWOT, 5_POURQUOI, RISQUE...), pour comprendre immediatement pourquoi
-- un levier existe. Un levier n'est generalement PAS issu d'une seule
-- analyse.
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

-- 1. Deplace le catalogue vers rf, ajoute les colonnes referentielles
ALTER TABLE mg.strategic_levers SET SCHEMA rf;

ALTER TABLE rf.strategic_levers
    ADD COLUMN domain_pillar_code character varying(10) REFERENCES mg.working_groups(pillar_code),
    ADD COLUMN family text,
    ADD COLUMN approval_status character varying(20) NOT NULL DEFAULT 'DRAFT';

ALTER TABLE rf.strategic_levers
    ADD CONSTRAINT chk_strategic_levers_approval_status CHECK (
        approval_status IN ('DRAFT', 'APPROVED', 'DEPRECATED')
    );

-- 2. Nouvelle table d'occurrence mg.lever_evidence
CREATE TABLE mg.lever_evidence (
    id                  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lever_code          text NOT NULL REFERENCES rf.strategic_levers(lever_code),
    analysis_id         integer NOT NULL REFERENCES osoa.strategic_analyses(id),
    evidence_type       character varying(20) NOT NULL,
    relevance_weight    numeric(4,2) NOT NULL,
    comment             text,
    created_at          timestamp without time zone NOT NULL DEFAULT now()
);

ALTER TABLE mg.lever_evidence
    ADD CONSTRAINT chk_lever_evidence_weight CHECK (
        relevance_weight >= 0 AND relevance_weight <= 1
    );

CREATE INDEX idx_lever_evidence_lever ON mg.lever_evidence (lever_code);
CREATE INDEX idx_lever_evidence_analysis ON mg.lever_evidence (analysis_id);

-- 3. Migre les donnees existantes (evidence_type derive de la vraie methode)
INSERT INTO mg.lever_evidence (lever_code, analysis_id, evidence_type, relevance_weight, created_at)
SELECT rcl.lever_code, rcl.analysis_id, sa.method, rcl.relevance_weight, rcl.created_at
FROM mg.root_cause_levers rcl
JOIN osoa.strategic_analyses sa ON sa.id = rcl.analysis_id;

DROP TABLE mg.root_cause_levers;

COMMIT;

-- Verification post-execution
\d rf.strategic_levers
\d mg.lever_evidence
SELECT * FROM mg.lever_evidence;
