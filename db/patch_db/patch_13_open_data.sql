-- ============================================================
-- OSA Observatory -- Sprint 13
-- Open Data -- Couche 0 publique
--
-- Perimetre :
--   pub.v_isa_country_latest     -- dernier score ISA par pays
--   pub.v_isa_country_history    -- historique scores 2010-2024
--   pub.v_isa_pillar_breakdown   -- scores par pilier 2020-2024
--   pub.v_isa_open_data_catalog  -- catalogue complet open data
--
-- Sources :
--   ma.v_isa_observed_scores_by_country_year
--   ma.v_isa_observed_scores_by_pillar
--   mg.v_public_p7j_recommendations
--   mg.v_public_p7i_amar_alerts
-- ============================================================

BEGIN;

-- ── 1. Score ISA le plus recent par pays ─────────────────────
CREATE OR REPLACE VIEW pub.v_isa_country_latest AS
SELECT
    s.country_iso3,
    s.year                                          AS reference_year,
    s.region_code,
    s.region_label,
    s.economic_region_code,
    s.economic_region_label,
    ROUND(s.isa_observed_score::numeric, 4)         AS isa_score,
    ROUND(s.sovereignty_observed_score::numeric, 4) AS sovereignty_score,
    ROUND(s.vulnerability_observed_score::numeric, 4) AS vulnerability_score,
    ROUND(s.resilience_observed_score::numeric, 4)  AS resilience_score,
    ROUND(s.avg_observation_confidence::numeric, 4) AS data_confidence,
    s.nb_pillars_observed,
    s.nb_indicators_observed,
    s.publication_status,
    -- Trajectoire P7J la plus recente (agregee sur tous les piliers)
    ROUND(AVG(p.intervention_priority_score)::numeric, 4) AS avg_intervention_priority,
    -- Distribution trajectoire
    COUNT(*) FILTER (WHERE p.trajectory_class = 'ACCELERATING') AS nb_pillars_accelerating,
    COUNT(*) FILTER (WHERE p.trajectory_class = 'PROGRESSING')  AS nb_pillars_progressing,
    COUNT(*) FILTER (WHERE p.trajectory_class = 'STABLE')       AS nb_pillars_stable,
    COUNT(*) FILTER (WHERE p.trajectory_class = 'DECLINING')    AS nb_pillars_declining,
    COUNT(*) FILTER (WHERE p.trajectory_class = 'CRITICAL')     AS nb_pillars_critical,
    -- Alerte AMAR
    a.risk_band                                     AS amar_risk_band,
    ROUND(a.risk_score::numeric, 4)                 AS amar_risk_score,
    -- Disclaimer
    'This index is an early-warning analytical tool. '
    'It does not constitute a legal, political or diplomatic qualification. '
    'OSA Observatory -- open.osa-observatory.org'   AS disclaimer
FROM ma.v_isa_observed_scores_by_country_year s
LEFT JOIN ma.v_p7j_recommendation_engine p
    ON  p.country_iso3 = s.country_iso3
    AND p.year         = s.year
LEFT JOIN mg.v_public_p7i_amar_alerts a
    ON  a.country_iso3 = s.country_iso3
    AND a.year         = s.year
WHERE s.year = (
    SELECT MAX(year)
    FROM ma.v_isa_observed_scores_by_country_year s2
    WHERE s2.country_iso3 = s.country_iso3
      AND s2.publication_status = 'OFFICIAL_CONSOLIDATED'
)
AND s.publication_status = 'OFFICIAL_CONSOLIDATED'
GROUP BY
    s.country_iso3, s.year, s.region_code, s.region_label,
    s.economic_region_code, s.economic_region_label,
    s.isa_observed_score, s.sovereignty_observed_score,
    s.vulnerability_observed_score, s.resilience_observed_score,
    s.avg_observation_confidence, s.nb_pillars_observed,
    s.nb_indicators_observed, s.publication_status,
    a.risk_band, a.risk_score;

COMMENT ON VIEW pub.v_isa_country_latest IS
'Sprint 13 -- Open Data -- Score ISA le plus recent par pays.
Inclut distribution trajectoire P7J et alerte AMAR.
Acces libre -- Couche 0.';

-- ── 2. Historique scores ISA 2010-2024 ───────────────────────
CREATE OR REPLACE VIEW pub.v_isa_country_history AS
SELECT
    s.country_iso3,
    s.year,
    s.region_code,
    s.region_label,
    ROUND(s.isa_observed_score::numeric, 4)           AS isa_score,
    ROUND(s.sovereignty_observed_score::numeric, 4)   AS sovereignty_score,
    ROUND(s.vulnerability_observed_score::numeric, 4) AS vulnerability_score,
    ROUND(s.resilience_observed_score::numeric, 4)    AS resilience_score,
    ROUND(s.avg_observation_confidence::numeric, 4)   AS data_confidence,
    s.nb_pillars_observed,
    s.publication_status,
    -- Delta annuel ISA
    ROUND((s.isa_observed_score - LAG(s.isa_observed_score)
        OVER (PARTITION BY s.country_iso3 ORDER BY s.year))::numeric, 4)
        AS isa_annual_delta,
    -- Alerte AMAR si disponible
    a.risk_band                                       AS amar_risk_band,
    'OSA Observatory -- open.osa-observatory.org'     AS source
FROM ma.v_isa_observed_scores_by_country_year s
LEFT JOIN mg.v_public_p7i_amar_alerts a
    ON  a.country_iso3 = s.country_iso3
    AND a.year         = s.year
WHERE s.publication_status = 'OFFICIAL_CONSOLIDATED'
ORDER BY s.country_iso3, s.year;

COMMENT ON VIEW pub.v_isa_country_history IS
'Sprint 13 -- Open Data -- Historique scores ISA 2010-2024 par pays.
Delta annuel calcule. Alerte AMAR associee.
Acces libre -- Couche 0.';

-- ── 3. Decomposition par pilier 2020-2024 ────────────────────
CREATE OR REPLACE VIEW pub.v_isa_pillar_breakdown AS
SELECT
    p.country_iso3,
    p.year,
    p.pillar_code,
    p.region_code,
    ROUND(p.isa_observed_score::numeric, 4)           AS pillar_isa_score,
    ROUND(p.sovereignty_observed_score::numeric, 4)   AS sovereignty_score,
    ROUND(p.vulnerability_observed_score::numeric, 4) AS vulnerability_score,
    ROUND(p.avg_observation_confidence::numeric, 4)   AS data_confidence,
    p.nb_indicators_observed,
    p.nb_valid_observations,
    p.nb_estimated_observations,
    -- Trajectoire P7J
    r.trajectory_class,
    r.trajectory_signal,
    r.intervention_family_label,
    r.intervention_priority_class,
    -- Action open data uniquement
    CASE r.trajectory_class
        WHEN 'ACCELERATING' THEN 'Trajectory: accelerating'
        WHEN 'PROGRESSING'  THEN 'Trajectory: progressing'
        WHEN 'STABLE'       THEN 'Trajectory: stable'
        WHEN 'DECLINING'    THEN 'Trajectory: declining'
        WHEN 'CRITICAL'     THEN 'Trajectory: critical -- see affiliated access'
        ELSE                     'Trajectory: under assessment'
    END                                               AS trajectory_label_en,
    'OSA Observatory -- open.osa-observatory.org'     AS source
FROM ma.v_isa_observed_scores_by_pillar p
LEFT JOIN ma.v_p7j_recommendation_engine r
    ON  r.country_iso3 = p.country_iso3
    AND r.year         = p.year
    AND r.pillar_code  = p.pillar_code
WHERE p.publication_status = 'OFFICIAL_CONSOLIDATED'
  AND p.year >= 2020
ORDER BY p.country_iso3, p.year, p.pillar_code;

COMMENT ON VIEW pub.v_isa_pillar_breakdown IS
'Sprint 13 -- Open Data -- Scores ISA par pilier 2020-2024.
Trajectoire P7J Couche 0 incluse.
Acces libre -- Couche 0.';

-- ── 4. Catalogue open data ────────────────────────────────────
CREATE OR REPLACE VIEW pub.v_isa_open_data_catalog AS
SELECT
    'ISA_COUNTRY_LATEST'    AS dataset_code,
    'Derniers scores ISA par pays'  AS dataset_label,
    54                      AS nb_countries,
    2024                    AS reference_year,
    2024                    AS year_from,
    2024                    AS year_to,
    'pub.v_isa_country_latest'      AS view_name,
    '/opendata/countries/latest'    AS api_endpoint,
    'JSON, CSV'             AS formats,
    'CC-BY-4.0'             AS license,
    TRUE                    AS open_access
UNION ALL
SELECT
    'ISA_COUNTRY_HISTORY',
    'Historique scores ISA 2010-2024',
    54, 2024, 2010, 2024,
    'pub.v_isa_country_history',
    '/opendata/countries/history',
    'JSON, CSV',
    'CC-BY-4.0',
    TRUE
UNION ALL
SELECT
    'ISA_PILLAR_BREAKDOWN',
    'Scores ISA par pilier 2020-2024',
    54, 2024, 2020, 2024,
    'pub.v_isa_pillar_breakdown',
    '/opendata/pillars',
    'JSON, CSV',
    'CC-BY-4.0',
    TRUE
UNION ALL
SELECT
    'ISA_AMAR_ALERTS',
    'Alertes precurseurs atrocites AMAR 2010-2024',
    54, 2024, 2010, 2024,
    'mg.v_public_p7i_amar_alerts',
    '/opendata/alerts/amar',
    'JSON, CSV',
    'CC-BY-4.0',
    TRUE
UNION ALL
SELECT
    'ISA_P7J_TRAJECTORIES',
    'Trajectoires souveraines P7J 2020-2024',
    54, 2024, 2020, 2024,
    'mg.v_public_p7j_recommendations',
    '/opendata/trajectories',
    'JSON, CSV',
    'CC-BY-4.0',
    TRUE
UNION ALL
SELECT
    'ISA_METHODOLOGY',
    'Documentation methodologique ISA v2',
    NULL, NULL, NULL, NULL,
    'pub.v_isa_public_methodology',
    '/opendata/methodology',
    'JSON',
    'CC-BY-4.0',
    TRUE;

COMMENT ON VIEW pub.v_isa_open_data_catalog IS
'Sprint 13 -- Catalogue des datasets open data OSA.
6 datasets -- licence CC-BY-4.0 -- acces libre.';

COMMIT;
