-- ============================================================
-- Sprint 31 -- Suppression des colonnes coverage_fr/en, orphelines
-- 4 juillet 2026
-- ============================================================
-- coverage_fr/en contenait une plage d'annees figee ("54 pays · 2010-2024"),
-- qui se serait perimee des l'ouverture de l'annee 2025 sans intervention
-- manuelle. L'endpoint /api/v2/sovereignty/poa-catalog calcule desormais
-- nb_countries/year_min/year_max a la volee a partir des observations
-- reellement publiees (jointure rf.publication_policy) -- ces deux colonnes
-- ne sont plus jamais lues par la requete API, elles sont orphelines.
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_db \
--     < sprint31_poa_catalog_drop_coverage.sql
-- ============================================================

BEGIN;

ALTER TABLE rf.poa_catalog
    DROP COLUMN IF EXISTS coverage_fr,
    DROP COLUMN IF EXISTS coverage_en;

COMMIT;

\d rf.poa_catalog
