-- ============================================================
-- Correction du perimetre d'annees en dur -- pub.mv_amar_dashboard
-- et pub.mv_geneco_dashboard
-- 19 juillet 2026
-- ============================================================
-- Remplace WHERE year BETWEEN 2020 AND 2024 (fige, sprint29_mv_
-- amar_geneco_dashboard.sql) par WHERE year IN (SELECT year FROM
-- rf.publication_policy WHERE status = 'OFFICIAL') -- pilote par
-- la table de reference, jamais de nouvelle recreation manuelle
-- necessaire quand une annee supplementaire passe OFFICIAL.
--
-- Zero dependance verifiee le 19 juillet 2026 sur osa_db (aucune
-- vue/objet ne depend de mv_amar_dashboard ou mv_geneco_dashboard)
-- avant execution de ce script -- DROP + CREATE, pas de CREATE OR
-- REPLACE (non supporte par PostgreSQL pour les vues materialisees).
--
-- A executer sur les 3 environnements (DEV, PREPROD, PROD) --
-- les deux vues existent deja sur les 3 (verifie le 19 juillet 2026).
-- ============================================================

BEGIN;

DROP MATERIALIZED VIEW IF EXISTS pub.mv_amar_dashboard;

CREATE MATERIALIZED VIEW pub.mv_amar_dashboard AS
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
WHERE year IN (SELECT year FROM rf.publication_policy WHERE status = 'OFFICIAL')
WITH DATA;

CREATE INDEX idx_mv_amar_dashboard_iso3_year
    ON pub.mv_amar_dashboard (country_iso3, year DESC);

DROP MATERIALIZED VIEW IF EXISTS pub.mv_geneco_dashboard;

CREATE MATERIALIZED VIEW pub.mv_geneco_dashboard AS
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
WHERE year IN (SELECT year FROM rf.publication_policy WHERE status = 'OFFICIAL')
WITH DATA;

CREATE INDEX idx_mv_geneco_dashboard_iso3_year
    ON pub.mv_geneco_dashboard (country_iso3, year DESC);

COMMIT;

-- Verification post-execution
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

-- Test performance -- doit rester de l'ordre de la milliseconde
EXPLAIN ANALYZE SELECT * FROM pub.mv_amar_dashboard WHERE country_iso3 = 'AGO' AND year = 2024;
