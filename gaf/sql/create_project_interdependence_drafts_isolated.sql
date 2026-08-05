-- ============================================================
-- mg.project_interdependence_drafts -- creation isolee
-- 5 aout 2026
-- ============================================================
-- Correctif : cette table n'a jamais ete creee. Le script original
-- (create_strategic_levers_and_project_interdep.sql) l'incluait dans
-- la MEME transaction que CREATE TABLE mg.strategic_levers, qui a
-- echoue des le premier essai (collision avec le catalogue existant,
-- Sprint OIM Lot 1/2) -- toute la transaction a donc ete annulee,
-- y compris cette table pourtant valide. Erreur reelle rencontree au
-- premier test du niveau Plan d'action de l'interdependance.
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

CREATE TABLE mg.project_interdependence_drafts (
    id                      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_code            character varying(60) NOT NULL REFERENCES rf.sovereign_project_catalog(project_code),
    content                 jsonb NOT NULL,
    status                  character varying(20) NOT NULL DEFAULT 'AI_DRAFTED',
    created_by              integer REFERENCES mg.affiliates(id),
    created_at              timestamp without time zone NOT NULL DEFAULT now(),
    updated_at              timestamp without time zone NOT NULL DEFAULT now()
);

ALTER TABLE mg.project_interdependence_drafts
    ADD CONSTRAINT chk_project_interdep_drafts_status CHECK (
        status IN ('AI_DRAFTED', 'HUMAN_VALIDATED')
    );

CREATE INDEX idx_project_interdep_drafts_project ON mg.project_interdependence_drafts (project_code);

COMMIT;

-- Verification post-execution
\d mg.project_interdependence_drafts
