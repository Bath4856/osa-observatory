-- ============================================================
-- Sprint 30 Lot A -- Ajout role COMITE_ETHIQUE
-- GAF Finding : EPARTICIPATION_ROLE_MATRIX_001
-- Contexte : preparation futur Indice Africain de Gouvernance (doctrine P7E)
-- Date : 29 juin 2026
-- ============================================================

BEGIN;

ALTER TABLE mg.affiliate_roles
    DROP CONSTRAINT chk_role_code;

ALTER TABLE mg.affiliate_roles
    ADD CONSTRAINT chk_role_code
    CHECK (role_code IN (
        'ADMIN',
        'COMITE_TECH',
        'COMITE_SCI',
        'COMITE_ETHIQUE',
        'AFFILIE',
        'OBSERVATEUR'
    ));

-- Verification
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conname = 'chk_role_code';

COMMIT;
