-- ============================================================
-- OSA Observatory -- Sprint 16
-- Vues materialisees -- Performance production
--
-- Probleme : temps de reponse inacceptables
--   rankings        : 100s -> cible < 1s
--   countries/latest: 121s -> cible < 1s
--   pillars         : 105s -> cible < 2s
--   countries list  :  21s -> cible < 1s
--
-- Solution : vues materialisees avec index
-- Refresh : apres chaque pipeline L3 (option [8])
-- ============================================================

BEGIN;

-- ── 1. mv_isa_country_latest ─────────────────────────────────
DROP MATERIALIZED VIEW IF EXISTS pub.mv_isa_country_latest CASCADE;
CREATE MATERIALIZED VIEW pub.mv_isa_country_latest AS
SELECT
    s.country_iso3,
    s.year                                              AS reference_year,
    COALESCE(ca.region_code, 'UNSPECIFIED')::VARCHAR(80) AS region_code,
    COALESCE(rg.name_fr, 'Non specifie')                AS region_label,
    s.economic_region_code,
    s.economic_region_label,
    CASE
        WHEN s.nb_pillars_observed >= 8 THEN 'FULL_COVERAGE'
        WHEN s.nb_pillars_observed >= 6 THEN 'PARTIAL_COVERAGE'
        ELSE 'LIMITED_COVERAGE'
    END                                                 AS data_coverage_class,
    s.nb_pillars_observed,
    COUNT(*) FILTER (WHERE p.trajectory_class = 'ACCELERATING') AS nb_pillars_accelerating,
    COUNT(*) FILTER (WHERE p.trajectory_class = 'PROGRESSING')  AS nb_pillars_progressing,
    COUNT(*) FILTER (WHERE p.trajectory_class = 'STABLE')       AS nb_pillars_stable,
    COUNT(*) FILTER (WHERE p.trajectory_class = 'DECLINING')    AS nb_pillars_declining,
    COUNT(*) FILTER (WHERE p.trajectory_class = 'CRITICAL')     AS nb_pillars_critical,
    CASE
        WHEN COUNT(*) FILTER (WHERE p.trajectory_class IN ('ACCELERATING','PROGRESSING'))
           > COUNT(*) FILTER (WHERE p.trajectory_class IN ('DECLINING','CRITICAL'))
        THEN 'POSITIVE_MOMENTUM'
        WHEN COUNT(*) FILTER (WHERE p.trajectory_class IN ('DECLINING','CRITICAL'))
           > COUNT(*) FILTER (WHERE p.trajectory_class IN ('ACCELERATING','PROGRESSING'))
        THEN 'NEGATIVE_MOMENTUM'
        ELSE 'MIXED_MOMENTUM'
    END                                                 AS sovereign_momentum,
    a.risk_band                                         AS amar_risk_band,
    'Subscribe at open.osa-observatory.org for scores, trend slopes and sovereign action recommendations.' AS affiliation_call,
    'OSA Observatory -- CC-BY-4.0 -- open.osa-observatory.org' AS source
FROM ma.v_isa_observed_scores_by_country_year s
LEFT JOIN rf.v_country_aliases ca ON ca.iso3 = s.country_iso3
LEFT JOIN rf.regions rg ON rg.code = ca.region_code
LEFT JOIN ma.v_p7j_recommendation_engine p
    ON  p.country_iso3 = s.country_iso3
    AND p.year         = s.year
LEFT JOIN mg.v_public_p7i_amar_alerts a
    ON  a.country_iso3 = s.country_iso3
    AND a.year         = s.year
WHERE s.year = (
    SELECT MAX(s2.year)
    FROM ma.v_isa_observed_scores_by_country_year s2
    WHERE s2.country_iso3       = s.country_iso3
      AND s2.publication_status = 'OFFICIAL_CONSOLIDATED'
)
AND s.publication_status = 'OFFICIAL_CONSOLIDATED'
GROUP BY
    s.country_iso3, s.year, ca.region_code, rg.name_fr,
    s.economic_region_code, s.economic_region_label,
    s.nb_pillars_observed, a.risk_band;

CREATE UNIQUE INDEX idx_mv_country_latest_pk
    ON pub.mv_isa_country_latest (country_iso3);
CREATE INDEX idx_mv_country_latest_region
    ON pub.mv_isa_country_latest (region_code);
CREATE INDEX idx_mv_country_latest_momentum
    ON pub.mv_isa_country_latest (sovereign_momentum);

COMMENT ON MATERIALIZED VIEW pub.mv_isa_country_latest IS
'Sprint 16 -- Vue materialisee country_latest.
Remplace pub.v_isa_country_latest pour les endpoints API.
Refresh apres pipeline L3 (option 8 restart_v2.ps1).';

-- ── 2. mv_isa_country_rankings ────────────────────────────────
DROP MATERIALIZED VIEW IF EXISTS pub.mv_isa_country_rankings CASCADE;
CREATE MATERIALIZED VIEW pub.mv_isa_country_rankings AS
SELECT
    s.country_iso3,
    s.year,
    COALESCE(ca.region_code, s.region_code)::VARCHAR(80) AS region_code,
    COALESCE(rg.name_fr, s.region_label)                AS region_label,
    ROUND(s.isa_observed_score::numeric, 4)             AS isa_observed_score,
    ROUND(s.sovereignty_observed_score::numeric, 4)     AS sovereignty_score,
    ROUND(s.vulnerability_observed_score::numeric, 4)   AS vulnerability_score,
    ROUND(s.resilience_observed_score::numeric, 4)      AS resilience_score,
    ROUND(s.avg_observation_confidence::numeric, 4)     AS data_confidence,
    s.nb_pillars_observed,
    RANK() OVER (
        PARTITION BY s.year
        ORDER BY s.isa_observed_score DESC NULLS LAST
    )                                                   AS isa_rank,
    RANK() OVER (
        PARTITION BY s.year, COALESCE(ca.region_code, s.region_code)
        ORDER BY s.isa_observed_score DESC NULLS LAST
    )                                                   AS regional_rank,
    ROUND(AVG(p.intervention_priority_score)::numeric, 4) AS avg_priority_score,
    COUNT(*) FILTER (WHERE p.trajectory_class = 'ACCELERATING') AS nb_pillars_accelerating,
    COUNT(*) FILTER (WHERE p.trajectory_class = 'CRITICAL')     AS nb_pillars_critical,
    CASE
        WHEN COUNT(*) FILTER (WHERE p.trajectory_class IN ('ACCELERATING','PROGRESSING'))
           > COUNT(*) FILTER (WHERE p.trajectory_class IN ('DECLINING','CRITICAL'))
        THEN 'POSITIVE_MOMENTUM'
        WHEN COUNT(*) FILTER (WHERE p.trajectory_class IN ('DECLINING','CRITICAL'))
           > COUNT(*) FILTER (WHERE p.trajectory_class IN ('ACCELERATING','PROGRESSING'))
        THEN 'NEGATIVE_MOMENTUM'
        ELSE 'MIXED_MOMENTUM'
    END                                                 AS sovereign_momentum,
    s.publication_status
FROM ma.v_isa_observed_scores_by_country_year s
LEFT JOIN rf.v_country_aliases ca ON ca.iso3 = s.country_iso3
LEFT JOIN rf.regions rg ON rg.code = ca.region_code
LEFT JOIN ma.v_p7j_recommendation_engine p
    ON  p.country_iso3 = s.country_iso3
    AND p.year         = s.year
WHERE s.publication_status = 'OFFICIAL_CONSOLIDATED'
GROUP BY
    s.country_iso3, s.year, ca.region_code, rg.name_fr,
    s.region_code, s.region_label, s.isa_observed_score,
    s.sovereignty_observed_score, s.vulnerability_observed_score,
    s.resilience_observed_score, s.avg_observation_confidence,
    s.nb_pillars_observed, s.publication_status;

CREATE UNIQUE INDEX idx_mv_rankings_pk
    ON pub.mv_isa_country_rankings (country_iso3, year);
CREATE INDEX idx_mv_rankings_year
    ON pub.mv_isa_country_rankings (year, isa_rank);
CREATE INDEX idx_mv_rankings_region
    ON pub.mv_isa_country_rankings (region_code, year);

COMMENT ON MATERIALIZED VIEW pub.mv_isa_country_rankings IS
'Sprint 16 -- Vue materialisee country_rankings.
Rang global + regional precalcule.
Refresh apres pipeline L3.';

-- ── 3. mv_isa_pillar_breakdown ────────────────────────────────
DROP MATERIALIZED VIEW IF EXISTS pub.mv_isa_pillar_breakdown CASCADE;
CREATE MATERIALIZED VIEW pub.mv_isa_pillar_breakdown AS
SELECT
    p.country_iso3,
    p.year,
    p.pillar_code,
    COALESCE(ca.region_code, p.region_code)::VARCHAR(80) AS region_code,
    r.trajectory_class,
    r.trajectory_signal,
    r.intervention_family_label,
    r.intervention_priority_class,
    CASE
        WHEN COALESCE(r.trend_slope,0) >  0.003 THEN 'STRONG_IMPROVEMENT'
        WHEN COALESCE(r.trend_slope,0) >  0.001 THEN 'IMPROVEMENT'
        WHEN COALESCE(r.trend_slope,0) >= -0.001 THEN 'STABLE'
        WHEN COALESCE(r.trend_slope,0) >= -0.003 THEN 'DETERIORATION'
        ELSE 'STRONG_DETERIORATION'
    END                                                 AS pillar_direction,
    p.nb_indicators_observed,
    'Subscribe for pillar scores, slopes and sovereign action recommendations.' AS affiliation_call,
    'OSA Observatory -- CC-BY-4.0'                     AS source
FROM ma.v_isa_observed_scores_by_pillar p
LEFT JOIN rf.v_country_aliases ca ON ca.iso3 = p.country_iso3
LEFT JOIN ma.v_p7j_recommendation_engine r
    ON  r.country_iso3 = p.country_iso3
    AND r.year         = p.year
    AND r.pillar_code  = p.pillar_code
WHERE p.publication_status = 'OFFICIAL_CONSOLIDATED'
  AND p.year >= 2020;

CREATE UNIQUE INDEX idx_mv_pillar_pk
    ON pub.mv_isa_pillar_breakdown (country_iso3, year, pillar_code);
CREATE INDEX idx_mv_pillar_country_year
    ON pub.mv_isa_pillar_breakdown (country_iso3, year);
CREATE INDEX idx_mv_pillar_trajectory
    ON pub.mv_isa_pillar_breakdown (trajectory_class, year);

COMMENT ON MATERIALIZED VIEW pub.mv_isa_pillar_breakdown IS
'Sprint 16 -- Vue materialisee pillar_breakdown.
2700 lignes precalculees (54 pays x 10 piliers x 5 ans).
Refresh apres pipeline L3.';

-- ── 4. Procedure de refresh ───────────────────────────────────
CREATE OR REPLACE FUNCTION pub.refresh_materialized_views()
RETURNS TEXT AS $$
DECLARE
    t0 TIMESTAMPTZ := NOW();
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY pub.mv_isa_country_latest;
    REFRESH MATERIALIZED VIEW CONCURRENTLY pub.mv_isa_country_rankings;
    REFRESH MATERIALIZED VIEW CONCURRENTLY pub.mv_isa_pillar_breakdown;
    RETURN 'OK -- ' || EXTRACT(EPOCH FROM (NOW() - t0))::INT || 's';
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION pub.refresh_materialized_views() IS
'Sprint 16 -- Refresh toutes les vues materialisees pub.*.
Appeler apres chaque pipeline L3.
Usage : SELECT pub.refresh_materialized_views();';

COMMIT;
