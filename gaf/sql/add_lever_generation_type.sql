-- ============================================================
-- mg.ai_generation_queue -- ajoute LEVER_GENERATION
-- 8 aout 2026
-- ============================================================
-- Chantier 540 : le levier doit devenir batchable, comme les analyses
-- primaires et leur revue, pour eviter les timeouts et respecter le
-- plafond de jetons OpenAI.
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

ALTER TABLE mg.ai_generation_queue
    DROP CONSTRAINT chk_ai_queue_generation_type;

ALTER TABLE mg.ai_generation_queue
    ADD CONSTRAINT chk_ai_queue_generation_type CHECK (
        generation_type IN ('VISION_SUMMARY', 'PLAN_ACTION_EXPLOSION', 'PRIMARY_ANALYSIS', 'ANALYSIS_REVIEW', 'LEVER_GENERATION')
    );

COMMIT;

\d mg.ai_generation_queue
