-- ============================================================
-- mg.summary_review -- verdict de THEO sur un resume executif
-- 7 aout 2026
-- ============================================================
-- Extension de la boucle SCRIBE/THEO au Niveau 0 (donnees ouvertes +
-- resume executif) -- demande explicite de Theo, priorite avant meme
-- la refonte complete OpportunityStudy (Niveau 1). Distinct de
-- mg.analysis_review (qui reference mg.pillar_analysis_drafts, un
-- brouillon d'analyse structuree) -- ici la cible est un livrable
-- (osoa.strategic_deliverables), et le contenu evalue est de la prose
-- libre bilingue, pas un schema Literal.
--
-- Reutilise la meme structure Regle/Preuve/Correction (issues jsonb)
-- que mg.analysis_review -- meme discipline, cible differente.
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

CREATE TABLE mg.summary_review (
    id                  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    deliverable_id      integer NOT NULL REFERENCES osoa.strategic_deliverables(id),
    review_status       character varying(20) NOT NULL,
    issues              jsonb NOT NULL DEFAULT '[]'::jsonb,
    created_at          timestamp without time zone NOT NULL DEFAULT now()
);

ALTER TABLE mg.summary_review
    ADD CONSTRAINT chk_summary_review_status CHECK (
        review_status IN ('CONFORME', 'A_REVOIR', 'PROBLEME_DETECTE')
    );

CREATE INDEX idx_summary_review_deliverable ON mg.summary_review (deliverable_id);

COMMIT;

-- Verification post-execution
\d mg.summary_review
