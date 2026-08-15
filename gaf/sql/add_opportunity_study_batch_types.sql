-- ============================================================
-- mg.ai_generation_queue -- OpportunityStudy a l'echelle
-- 14 aout 2026
-- ============================================================
-- 3 nouveaux types, distincts de PRIMARY_ANALYSIS/REGENERATION/
-- ANALYSIS_REVIEW car ils ciblent une table differente
-- (osoa.strategic_deliverables, pas mg.pillar_analysis_drafts).
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

ALTER TABLE mg.ai_generation_queue
    DROP CONSTRAINT chk_ai_queue_generation_type;

ALTER TABLE mg.ai_generation_queue
    ADD CONSTRAINT chk_ai_queue_generation_type CHECK (
        generation_type IN (
            'VISION_SUMMARY', 'PLAN_ACTION_EXPLOSION', 'PRIMARY_ANALYSIS',
            'ANALYSIS_REVIEW', 'LEVER_GENERATION', 'SUMMARY_REVIEW',
            'REGENERATION', 'OPPORTUNITY_STUDY_GENERATION',
            'OPPORTUNITY_STUDY_REVIEW', 'OPPORTUNITY_STUDY_REGENERATION'
        )
    );

COMMIT;

\d mg.ai_generation_queue
