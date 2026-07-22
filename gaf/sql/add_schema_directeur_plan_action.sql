-- ============================================================
-- osoa.strategic_deliverables -- ajout SCHEMA_DIRECTEUR + PLAN_ACTION
-- 22 juillet 2026
-- ============================================================
-- Complete les 4 livrables du brouillon exploratoire (2 deja
-- construits ce soir : ETUDE_OPPORTUNITE, ETUDE_FAISABILITE).
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

ALTER TABLE osoa.strategic_deliverables
    DROP CONSTRAINT strategic_deliverables_deliverable_type_check;

ALTER TABLE osoa.strategic_deliverables
    ADD CONSTRAINT strategic_deliverables_deliverable_type_check CHECK (
        deliverable_type IN (
            'ETUDE_OPPORTUNITE', 'ETUDE_FAISABILITE', 'SCHEMA_DIRECTEUR', 'PLAN_ACTION'
        )
    );

COMMIT;

-- Verification post-execution
\d osoa.strategic_deliverables
