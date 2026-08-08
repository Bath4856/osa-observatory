-- ============================================================
-- mg.ai_generation_queue -- ajoute SUMMARY_REVIEW
-- 8 aout 2026
-- ============================================================
-- Chantier 540 : THEO doit aussi relire les resumes executifs a
-- l'echelle (une fois SCRIBE termine, doctrine des 2 phases strictes)
-- -- pas seulement les 9 analyses primaires.
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

ALTER TABLE mg.ai_generation_queue
    DROP CONSTRAINT chk_ai_queue_generation_type;

ALTER TABLE mg.ai_generation_queue
    ADD CONSTRAINT chk_ai_queue_generation_type CHECK (
        generation_type IN ('VISION_SUMMARY', 'PLAN_ACTION_EXPLOSION', 'PRIMARY_ANALYSIS', 'ANALYSIS_REVIEW', 'LEVER_GENERATION', 'SUMMARY_REVIEW')
    );

COMMIT;

\d mg.ai_generation_queue
