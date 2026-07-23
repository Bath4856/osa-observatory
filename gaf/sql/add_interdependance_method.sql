-- ============================================================
-- osoa.strategic_analyses -- ajout de la methode INTERDEPENDANCE
-- 23 juillet 2026
-- ============================================================
-- 10eme methode d'analyse strategique -- capture l'interdependance
-- entre piliers et/ou indicateurs POA, EXCLUSIVEMENT dans le
-- contexte d'un pays specifique (country_iso3 obligatoire dans le
-- contenu, jamais deduit implicitement -- mg.project_families et
-- mg.transformation_requirements n'ont pas de colonne pays directe,
-- verifie le 23 juillet 2026).
--
-- Remplace la table rf.poa_pillar_interdependence abandonnee la
-- veille (drop_poa_pillar_interdependence.sql, 22-23 juillet 2026) --
-- cette fois correctement modelisee comme analyse pays-specifique
-- (une methode de plus, pas un referentiel general panafricain).
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

ALTER TABLE osoa.strategic_analyses
    DROP CONSTRAINT strategic_analyses_method_check;

ALTER TABLE osoa.strategic_analyses
    ADD CONSTRAINT strategic_analyses_method_check CHECK (
        method IN (
            '5W1H', 'SWOT', '5_POURQUOI', 'RISQUE', 'FAISABILITE',
            'MULTICRITERE', 'ECONOMIQUE', 'GOUVERNANCE', 'ZACHMAN',
            'INTERDEPENDANCE'
        )
    );

COMMIT;

-- Verification post-execution
\d osoa.strategic_analyses
