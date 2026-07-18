-- ============================================================
-- Raccordement final -- mg.transformation_requirements.opportunity_id
-- Complete la contrainte partielle posee avant la construction du
-- schema osoa. Ferme la boucle du chemin externe (Volume 0 OIM ch.5.2).
-- 17 juillet 2026
-- ============================================================

BEGIN;

ALTER TABLE mg.transformation_requirements
    ADD COLUMN IF NOT EXISTS opportunity_id integer REFERENCES osoa.opportunities(id);

ALTER TABLE mg.transformation_requirements
    DROP CONSTRAINT chk_transformation_req_origin;

ALTER TABLE mg.transformation_requirements
    ADD CONSTRAINT chk_transformation_req_origin
    CHECK (
        (origin_type = 'INTERNAL' AND objective_id IS NOT NULL AND opportunity_id IS NULL)
        OR (origin_type = 'EXTERNAL' AND objective_id IS NULL AND opportunity_id IS NOT NULL)
    );

COMMENT ON COLUMN mg.transformation_requirements.opportunity_id IS
    'Renseigne uniquement si origin_type = EXTERNAL -- le dossier OSOA qui a declenche la reconstruction a posteriori de ce besoin de transformation. Volume 0 OIM chapitre 5.2.';

COMMIT;

-- Verification post-execution
SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint
    WHERE conrelid = 'mg.transformation_requirements'::regclass AND conname = 'chk_transformation_req_origin';
