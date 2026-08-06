-- ============================================================
-- mg.ai_generation_queue -- retire la FK target_id (polymorphe)
-- 6 aout 2026
-- ============================================================
-- Bug reel decouvert lors du premier test a l'echelle (Theo, "grandeur
-- nature") : target_id referencait uniquement osoa.strategic_deliverables
-- (valable pour VISION_SUMMARY/PLAN_ACTION_EXPLOSION), mais
-- PRIMARY_ANALYSIS cible mg.pillar_strategic_vision et ANALYSIS_REVIEW
-- cible mg.pillar_analysis_drafts -- target_id est desormais polymorphe
-- selon generation_type, une seule FK ne peut plus etre correcte.
--
-- Le premier test (vision id=8) avait reussi PAR COINCIDENCE (un
-- livrable id=8 existait aussi, pour une autre vision) -- la vision
-- id=11 a revele le vrai probleme.
--
-- Le code applicatif verifie deja l'existence de la cible avant mise
-- en file (vision/draft/deliverable) -- retirer la FK est sur.
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

ALTER TABLE mg.ai_generation_queue
    DROP CONSTRAINT ai_generation_queue_target_id_fkey;

COMMIT;

-- Verification post-execution
\d mg.ai_generation_queue
