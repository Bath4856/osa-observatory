-- ============================================================
-- mg.ai_generation_queue -- retry_count + DEAD_LETTER
-- 11 aout 2026
-- ============================================================
-- Machine a etats idempotente demandee par Theo (suite a l'analyse
-- du bug du lot orphelin 9) : chaque echec incremente retry_count et
-- repasse a QUEUED pour un nouvel essai automatique, jusqu'a un seuil
-- de tolerance -- au-dela, l'element est isole en DEAD_LETTER (file
-- d'erreurs separee, inspectee manuellement/par THEO, ne bloque jamais
-- le reste d'une vague).
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

ALTER TABLE mg.ai_generation_queue
    ADD COLUMN retry_count integer NOT NULL DEFAULT 0;

ALTER TABLE mg.ai_generation_queue
    DROP CONSTRAINT chk_ai_queue_status;

ALTER TABLE mg.ai_generation_queue
    ADD CONSTRAINT chk_ai_queue_status CHECK (
        status IN ('QUEUED', 'SUBMITTED', 'COMPLETED', 'FAILED', 'DEAD_LETTER')
    );

COMMIT;

\d mg.ai_generation_queue
