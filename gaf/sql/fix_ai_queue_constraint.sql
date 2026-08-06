-- ============================================================
-- mg.ai_generation_queue -- ajoute PRIMARY_ANALYSIS
-- 5 aout 2026
-- ============================================================
-- Correctif suite a l'echec reel : la contrainte CHECK n'acceptait que
-- VISION_SUMMARY et PLAN_ACTION_EXPLOSION (valeurs d'origine, avant que
-- le pipeline batch soit etendu aux 9 analyses primaires). Erreur
-- rencontree au premier test de queue-analyses.
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

ALTER TABLE mg.ai_generation_queue
    DROP CONSTRAINT chk_ai_queue_generation_type;

ALTER TABLE mg.ai_generation_queue
    ADD CONSTRAINT chk_ai_queue_generation_type CHECK (
        generation_type IN ('VISION_SUMMARY', 'PLAN_ACTION_EXPLOSION', 'PRIMARY_ANALYSIS')
    );

COMMIT;

-- Verification post-execution
\d mg.ai_generation_queue
