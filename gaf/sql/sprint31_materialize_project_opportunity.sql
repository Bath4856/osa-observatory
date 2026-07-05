-- ============================================================
-- Sprint 31 -- Materialisation de la chaine de recommandation
-- 386ms mesures sur une simple lecture 1 ligne (8100 lignes sous-jacentes,
-- vues empilees non materialisees) -- meme classe de probleme que
-- AMAR/GENECO (Sprint 29 Lot C, 48s -> 74ms apres materialisation).
-- 3 juillet 2026
-- ============================================================
-- Les vues source (ma.v_isa_swot_signal_engine, ma.v_isa_strategic_
-- recommendation_engine, ma.v_isa_project_opportunity_catalog) restent
-- inchangees -- cette vue materialisee s'ajoute a cote, ne remplace rien.
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_db \
--     < sprint31_materialize_project_opportunity.sql
-- ============================================================

BEGIN;

DROP MATERIALIZED VIEW IF EXISTS ma.mv_isa_project_opportunity_catalog;

CREATE MATERIALIZED VIEW ma.mv_isa_project_opportunity_catalog AS
SELECT * FROM ma.v_isa_project_opportunity_catalog;

-- Index unique requis pour permettre REFRESH MATERIALIZED VIEW CONCURRENTLY
-- (verifie 1:1 : 8100 lignes = 54 pays x 15 annees x 10 piliers, aucun doublon)
CREATE UNIQUE INDEX idx_mv_isa_project_opp_country_pillar_year
    ON ma.mv_isa_project_opportunity_catalog (country_iso3, pillar_code, year);

-- Index de recherche pour le pattern de l'endpoint (country + pillar, tri par annee)
CREATE INDEX idx_mv_isa_project_opp_lookup
    ON ma.mv_isa_project_opportunity_catalog (country_iso3, pillar_code, year DESC);

COMMIT;

-- Verification post-execution : compter les lignes + mesurer le temps de lecture
\timing on
SELECT count(*) FROM ma.mv_isa_project_opportunity_catalog;
SELECT * FROM ma.mv_isa_project_opportunity_catalog
WHERE country_iso3 = 'ZAF' AND pillar_code = 'PENV'
ORDER BY year DESC LIMIT 1;
