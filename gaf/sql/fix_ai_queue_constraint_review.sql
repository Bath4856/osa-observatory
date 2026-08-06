-- ============================================================
-- mg.ai_generation_queue -- ajoute ANALYSIS_REVIEW
-- 6 aout 2026
-- ============================================================
-- THEO (reviseur) devient batchable, sur le meme patron que SCRIBE --
-- necessaire pour un test grandeur nature representatif de la
-- procedure annuelle reelle (Theo, 6 aout 2026).
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

ALTER TABLE mg.ai_generation_queue
    DROP CONSTRAINT chk_ai_queue_generation_type;

ALTER TABLE mg.ai_generation_queue
    ADD CONSTRAINT chk_ai_queue_generation_type CHECK (
        generation_type IN ('VISION_SUMMARY', 'PLAN_ACTION_EXPLOSION', 'PRIMARY_ANALYSIS', 'ANALYSIS_REVIEW')
    );

COMMIT;

-- Verification post-execution
\d mg.ai_generation_queue
