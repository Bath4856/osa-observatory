-- ============================================================
-- Sprint 29 -- Vues materialisees AMAR et GENECO
-- Performance : ~40ms vs 47-112s pour les vues simples
-- Perimetre : 2020-2024 (annees de publication officielle OSA)
-- 25 juin 2026
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_db \
--     < sprint29_mv_amar_geneco_dashboard.sql
-- ============================================================
-- NOTE : ces vues sont deja creees en production (Sprint 29).
-- Ce fichier est la reference documentaire et permet la
-- recreation en cas de besoin (REFRESH ou DROP/CREATE).
-- ============================================================

-- ============================================================
-- 1. pub.mv_amar_dashboard
--    Source : ma.v_p7i_amar_dashboard
--    Contenu : 6 facteurs d'alerte AMAR + score + band
--    Lignes : 270 (54 pays x 5 ans 2020-2024)
-- ============================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS pub.mv_amar_dashboard AS
SELECT
    country_iso3,
    year,
    risk_band,
    risk_score,
    confidence_score,
    recommended_action,
    public_narrative,
    structural_fragility_score,
    conflict_escalation_score,
    governance_breakdown_score,
    humanitarian_stress_score,
    resource_conflict_score,
    information_polarization_score
FROM ma.v_p7i_amar_dashboard
WHERE year BETWEEN 2020 AND 2024
WITH DATA;

CREATE INDEX IF NOT EXISTS idx_mv_amar_dashboard_iso3_year
    ON pub.mv_amar_dashboard (country_iso3, year DESC);

-- ============================================================
-- 2. pub.mv_geneco_dashboard
--    Source : ma.v_p7i_amar_geneco_dashboard
--    Contenu : 5 facteurs d'exposition GENECO + score + band
--    Lignes : 270 (54 pays x 5 ans 2020-2024)
-- ============================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS pub.mv_geneco_dashboard AS
SELECT
    country_iso3,
    year,
    risk_band,
    risk_score,
    confidence_score,
    risk_class,
    recommended_action,
    resource_capture_risk,
    logistics_enabling_risk,
    institutional_capture_risk,
    civilian_exploitation_risk,
    narrative_weaponization_risk
FROM ma.v_p7i_amar_geneco_dashboard
WHERE year BETWEEN 2020 AND 2024
WITH DATA;

CREATE INDEX IF NOT EXISTS idx_mv_geneco_dashboard_iso3_year
    ON pub.mv_geneco_dashboard (country_iso3, year DESC);

-- ============================================================
-- 3. Verification
-- ============================================================

SELECT
    'pub.mv_amar_dashboard'   AS vue,
    COUNT(*)                  AS lignes,
    MIN(year)                 AS annee_min,
    MAX(year)                 AS annee_max,
    COUNT(DISTINCT country_iso3) AS pays
FROM pub.mv_amar_dashboard

UNION ALL

SELECT
    'pub.mv_geneco_dashboard' AS vue,
    COUNT(*)                  AS lignes,
    MIN(year)                 AS annee_min,
    MAX(year)                 AS annee_max,
    COUNT(DISTINCT country_iso3) AS pays
FROM pub.mv_geneco_dashboard;

-- ============================================================
-- 4. Rafraichissement annuel (a executer apres chaque
--    mise a jour des donnees officielles)
-- ============================================================
-- REFRESH MATERIALIZED VIEW CONCURRENTLY pub.mv_amar_dashboard;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY pub.mv_geneco_dashboard;
-- ============================================================
