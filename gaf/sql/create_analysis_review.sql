-- ============================================================
-- mg.analysis_review -- verdict du reviseur IA par brouillon
-- 6 aout 2026
-- ============================================================
-- Necessaire pour la validation a l'echelle (540 visions x 9 analyses =
-- 4860/an) : un agent IA REVISEUR (role distinct du redacteur) juge
-- chaque brouillon contre les vraies donnees et les regles doctrinales
-- deja etablies -- ne re-rédige jamais, seulement critique. Permet une
-- validation humaine groupee pour le CONFORME, une revue individuelle
-- pour le reste -- jamais une validation automatique sans acte humain
-- explicite (bulk-validate-conforme reste un choix delibere de faire
-- confiance au reviseur, pas un automatisme cache).
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

CREATE TABLE mg.analysis_review (
    id                  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    draft_id            integer NOT NULL REFERENCES mg.pillar_analysis_drafts(id),
    review_status       character varying(20) NOT NULL,
    review_comment_fr   text NOT NULL,
    created_at          timestamp without time zone NOT NULL DEFAULT now()
);

ALTER TABLE mg.analysis_review
    ADD CONSTRAINT chk_analysis_review_status CHECK (
        review_status IN ('CONFORME', 'A_REVOIR', 'PROBLEME_DETECTE')
    );

CREATE INDEX idx_analysis_review_draft ON mg.analysis_review (draft_id);

COMMIT;

-- Verification post-execution
\d mg.analysis_review
