-- ============================================================
-- Correctif de la contrainte chk_transformation_req_origin_partial --
-- trop permissive, acceptait EXTERNAL avec objective_id renseigne (cas
-- teste et confirme le 17 juillet 2026 -- INSERT accepte a tort).
-- Contrainte rendue symetrique : chaque origine impose exactement l'etat
-- attendu de objective_id, dans les deux sens.
-- ============================================================

BEGIN;

ALTER TABLE mg.transformation_requirements
    DROP CONSTRAINT chk_transformation_req_origin_partial;

ALTER TABLE mg.transformation_requirements
    ADD CONSTRAINT chk_transformation_req_origin
    CHECK (
        (origin_type = 'INTERNAL' AND objective_id IS NOT NULL)
        OR (origin_type = 'EXTERNAL' AND objective_id IS NULL)
    );

COMMIT;

-- Verification post-execution
SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint
    WHERE conrelid = 'mg.transformation_requirements'::regclass AND conname = 'chk_transformation_req_origin';
