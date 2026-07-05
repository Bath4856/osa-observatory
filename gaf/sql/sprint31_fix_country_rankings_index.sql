-- ============================================================
-- Sprint 31 -- Correctif : index unique manquant sur
-- pub.mv_isa_country_rankings (Sprint 16, jamais indexee)
-- 4 juillet 2026
-- ============================================================
-- Constat : pub.refresh_materialized_views() echouait sur
-- "cannot refresh materialized view ... concurrently" car cette vue
-- n'a jamais eu d'index du tout depuis sa creation Sprint 16.
-- Cle naturelle verifiee unique (country_iso3, year) -- aucun doublon
-- (SELECT ... GROUP BY ... HAVING count(*) > 1 -- 0 lignes).
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_db \
--     < sprint31_fix_country_rankings_index.sql
-- ============================================================

BEGIN;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_isa_country_rankings_pk
    ON pub.mv_isa_country_rankings (country_iso3, year);

COMMIT;

-- Nouveau test complet -- doit reussir cette fois pour les 5 vues
SELECT pub.refresh_materialized_views();
