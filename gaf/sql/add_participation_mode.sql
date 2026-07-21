-- ============================================================
-- osoa.opportunities -- ajout de participation_mode
-- 20 juillet 2026
-- ============================================================
-- Nouvelle dimension, orthogonale a origin_type (qui a depose
-- l'opportunite) : quel role joue OSA dans cette opportunite.
--   - PROVIDER            : OSA est prestataire principal (cas DP)
--   - CONSORTIUM_PARTNER  : OSA est partenaire technique dans un
--                           consortium mene par un tiers (nouveau
--                           cas -- un externe depose un AMI/AO/AOI
--                           et demande la participation d'OSA)
--   - WATCH_ONLY          : veille, aucun engagement d'OSA
--
-- INTERNAL (OIM) : participation_mode toujours NULL -- dimension
-- non pertinente pour les interventions internes.
-- EXTERNAL (OSOA) : participation_mode obligatoire.
--   - PROVIDER exige deliverable_id (catalogue gtm.deliverables --
--     le livrable est porte par OSA)
--   - CONSORTIUM_PARTNER / WATCH_ONLY : deliverable_id NULL -- le
--     livrable final n'est pas necessairement dans le catalogue
--     OSA si OSA n'est que partenaire technique.
--
-- A executer DEV -> PREPROD -> PROD, dans cet ordre (doctrine du
-- projet). Contrainte CHECK, pas de verification de dependances
-- necessaire (contrairement a un DROP MATERIALIZED VIEW).
-- ============================================================

BEGIN;

ALTER TABLE osoa.opportunities
    ADD COLUMN participation_mode character varying(20);

ALTER TABLE osoa.opportunities
    DROP CONSTRAINT chk_osoa_opportunities_origin;

ALTER TABLE osoa.opportunities
    ADD CONSTRAINT chk_osoa_opportunities_origin CHECK (
        (
            origin_type = 'INTERNAL'
            AND origin_project_family_id IS NOT NULL
            AND client_id IS NULL
            AND deliverable_id IS NULL
            AND participation_mode IS NULL
        )
        OR
        (
            origin_type = 'EXTERNAL'
            AND origin_project_family_id IS NULL
            AND client_id IS NOT NULL
            AND participation_mode IS NOT NULL
            AND (
                (participation_mode = 'PROVIDER' AND deliverable_id IS NOT NULL)
                OR
                (participation_mode IN ('CONSORTIUM_PARTNER', 'WATCH_ONLY') AND deliverable_id IS NULL)
            )
        )
    );

ALTER TABLE osoa.opportunities
    ADD CONSTRAINT chk_osoa_opportunities_participation_mode CHECK (
        participation_mode IS NULL
        OR participation_mode IN ('PROVIDER', 'CONSORTIUM_PARTNER', 'WATCH_ONLY')
    );

COMMIT;

-- Verification post-execution
\d osoa.opportunities
