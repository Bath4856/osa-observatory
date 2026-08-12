-- ============================================================
-- mg.ai_generation_queue -- ajoute REGENERATION
-- 12 aout 2026
-- ============================================================
-- Permet de regenerer les analyses A_REVOIR/PROBLEME_DETECTE en masse
-- via le pipeline batch, avec dry_run reel pour estimer le cout avant
-- la relance complete de la campagne 2020.
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

ALTER TABLE mg.ai_generation_queue
    DROP CONSTRAINT chk_ai_queue_generation_type;

ALTER TABLE mg.ai_generation_queue
    ADD CONSTRAINT chk_ai_queue_generation_type CHECK (
        generation_type IN ('VISION_SUMMARY', 'PLAN_ACTION_EXPLOSION', 'PRIMARY_ANALYSIS', 'ANALYSIS_REVIEW', 'LEVER_GENERATION', 'SUMMARY_REVIEW', 'REGENERATION')
    );

COMMIT;

\d mg.ai_generation_queue
