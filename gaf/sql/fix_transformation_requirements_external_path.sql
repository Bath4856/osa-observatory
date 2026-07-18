-- ============================================================
-- ADR-007 (OIM), correctif -- mg.transformation_requirements doit
-- accepter le chemin externe (OSOA), sans Objectif strategique
-- prealable -- Volume 0 OIM, chapitre 5.2 : "OIM... reconstruit a
-- posteriori le Transformation Requirement... sans qu'aucun Objectif
-- strategique n'ait ete formule au prealable".
-- 17 juillet 2026
-- ============================================================
-- Bug reel dans le schema Phase 1 livre plus tot ce soir : objective_id
-- etait NOT NULL, rendant structurellement impossible tout besoin de
-- transformation issu du chemin externe. Corrige ici en deux temps :
-- (1) ce script (objective_id nullable + origin_type) ; (2) une fois
-- osoa.opportunities construite, ajout de opportunity_id (FK nullable)
-- et de la contrainte de coherence complete origin_type/objective_id/
-- opportunity_id.
-- A executer sur DEV en premier.
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_dev \
--     < fix_transformation_requirements_external_path.sql
-- ============================================================

BEGIN;

ALTER TABLE mg.transformation_requirements
    ALTER COLUMN objective_id DROP NOT NULL;

ALTER TABLE mg.transformation_requirements
    ADD COLUMN IF NOT EXISTS origin_type varchar(20) NOT NULL DEFAULT 'INTERNAL'
    CHECK (origin_type IN ('INTERNAL', 'EXTERNAL'));

-- Coherence partielle -- version complete une fois opportunity_id ajoute
-- (etape suivante, apres construction du schema osoa).
ALTER TABLE mg.transformation_requirements
    ADD CONSTRAINT chk_transformation_req_origin_partial
    CHECK (
        (origin_type = 'INTERNAL' AND objective_id IS NOT NULL)
        OR (origin_type = 'EXTERNAL')
    );

COMMENT ON COLUMN mg.transformation_requirements.origin_type IS
    'INTERNAL : issu du chemin ADR-006 (5 Pourquoi -> Objectif strategique), objective_id obligatoire. EXTERNAL : reconstruit a posteriori pour une opportunite qualifiee par OSOA, objective_id absent -- Volume 0 OIM chapitre 5.2.';

COMMIT;

-- Verification post-execution
SELECT column_name, is_nullable FROM information_schema.columns
    WHERE table_schema = 'mg' AND table_name = 'transformation_requirements' AND column_name IN ('objective_id', 'origin_type');
