-- ============================================================
-- OSA Observatory -- Sprint 13
-- Correction architecture Open Data -- 3 couches distinctes
-- + Catalogue opportunites projets structurants
--
-- Couche 0 (public) :
--   trajectoire + direction + alerte AMAR + opportunites
--   PAS de scores absolus
--
-- Couche 1 (affilie standard) :
--   scores absolus + pentes + actions souveraines
--
-- Couche 2 (affilie premium) :
--   simulations + IC P5-P95 + AMAR complet
-- ============================================================

BEGIN;

-- ── 1. Couche 0 -- Score ISA le plus recent (sans score absolu) ──
CREATE OR REPLACE VIEW pub.v_isa_country_latest AS
SELECT
    s.country_iso3,
    s.year                                              AS reference_year,
    s.region_code,
    s.region_label,
    s.economic_region_code,
    s.economic_region_label,
    -- Direction ISA (qualitatif -- pas de score absolu en Couche 0)
    CASE
        WHEN s.nb_pillars_observed >= 8 THEN 'FULL_COVERAGE'
        WHEN s.nb_pillars_observed >= 6 THEN 'PARTIAL_COVERAGE'
        ELSE                                 'LIMITED_COVERAGE'
    END                                                 AS data_coverage_class,
    s.nb_pillars_observed,
    -- Distribution trajectoire P7J (Couche 0)
    COUNT(*) FILTER (WHERE p.trajectory_class = 'ACCELERATING') AS nb_pillars_accelerating,
    COUNT(*) FILTER (WHERE p.trajectory_class = 'PROGRESSING')  AS nb_pillars_progressing,
    COUNT(*) FILTER (WHERE p.trajectory_class = 'STABLE')       AS nb_pillars_stable,
    COUNT(*) FILTER (WHERE p.trajectory_class = 'DECLINING')    AS nb_pillars_declining,
    COUNT(*) FILTER (WHERE p.trajectory_class = 'CRITICAL')     AS nb_pillars_critical,
    -- Signal global de trajectoire
    CASE
        WHEN COUNT(*) FILTER (WHERE p.trajectory_class IN ('ACCELERATING','PROGRESSING'))
           > COUNT(*) FILTER (WHERE p.trajectory_class IN ('DECLINING','CRITICAL'))
        THEN 'POSITIVE_MOMENTUM'
        WHEN COUNT(*) FILTER (WHERE p.trajectory_class IN ('DECLINING','CRITICAL'))
           > COUNT(*) FILTER (WHERE p.trajectory_class IN ('ACCELERATING','PROGRESSING'))
        THEN 'NEGATIVE_MOMENTUM'
        ELSE 'MIXED_MOMENTUM'
    END                                                 AS sovereign_momentum,
    -- Alerte AMAR (bande uniquement -- pas de score)
    a.risk_band                                         AS amar_risk_band,
    -- Appel a affiliation
    'Subscribe at open.osa-observatory.org for scores, '
    'trend slopes and sovereign action recommendations.' AS affiliation_call,
    -- Disclaimer
    'OSA Observatory -- CC-BY-4.0 -- open.osa-observatory.org' AS source
FROM ma.v_isa_observed_scores_by_country_year s
LEFT JOIN ma.v_p7j_recommendation_engine p
    ON  p.country_iso3 = s.country_iso3
    AND p.year         = s.year
LEFT JOIN mg.v_public_p7i_amar_alerts a
    ON  a.country_iso3 = s.country_iso3
    AND a.year         = s.year
WHERE s.year = (
    SELECT MAX(s2.year)
    FROM   ma.v_isa_observed_scores_by_country_year s2
    WHERE  s2.country_iso3       = s.country_iso3
      AND  s2.publication_status = 'OFFICIAL_CONSOLIDATED'
)
AND s.publication_status = 'OFFICIAL_CONSOLIDATED'
GROUP BY
    s.country_iso3, s.year, s.region_code, s.region_label,
    s.economic_region_code, s.economic_region_label,
    s.nb_pillars_observed, a.risk_band;

COMMENT ON VIEW pub.v_isa_country_latest IS
'Sprint 13 -- Open Data Couche 0 -- Etat souverain le plus recent.
Trajectoire P7J + momentum + alerte AMAR.
Pas de score absolu -- scores disponibles en Couche 1 (affilie standard).
CC-BY-4.0 -- open.osa-observatory.org';

-- ── 2. Couche 0 -- Historique directionnel (sans scores absolus) ──
CREATE OR REPLACE VIEW pub.v_isa_country_history AS
SELECT
    s.country_iso3,
    s.year,
    s.region_code,
    s.region_label,
    -- Direction annuelle (qualitatif)
    CASE
        WHEN s.isa_observed_score > LAG(s.isa_observed_score)
             OVER (PARTITION BY s.country_iso3 ORDER BY s.year) + 0.005
        THEN 'IMPROVING'
        WHEN s.isa_observed_score < LAG(s.isa_observed_score)
             OVER (PARTITION BY s.country_iso3 ORDER BY s.year) - 0.005
        THEN 'DETERIORATING'
        ELSE 'STABLE'
    END                                                 AS annual_direction,
    -- Alerte AMAR (bande uniquement)
    a.risk_band                                         AS amar_risk_band,
    s.nb_pillars_observed,
    s.publication_status,
    'Subscribe at open.osa-observatory.org for exact '
    'scores and trend analysis.'                        AS affiliation_call,
    'OSA Observatory -- CC-BY-4.0 -- open.osa-observatory.org' AS source
FROM ma.v_isa_observed_scores_by_country_year s
LEFT JOIN mg.v_public_p7i_amar_alerts a
    ON  a.country_iso3 = s.country_iso3
    AND a.year         = s.year
WHERE s.publication_status = 'OFFICIAL_CONSOLIDATED'
ORDER BY s.country_iso3, s.year;

COMMENT ON VIEW pub.v_isa_country_history IS
'Sprint 13 -- Open Data Couche 0 -- Direction souveraine 2020-2024.
Direction qualitative (IMPROVING/STABLE/DETERIORATING) sans score absolu.
Scores disponibles en Couche 1 (affilie standard).
CC-BY-4.0 -- open.osa-observatory.org';

-- ── 3. Couche 0 -- Decomposition piliers (trajectoire uniquement) ──
CREATE OR REPLACE VIEW pub.v_isa_pillar_breakdown AS
SELECT
    p.country_iso3,
    p.year,
    p.pillar_code,
    p.region_code,
    -- Trajectoire P7J (Couche 0)
    r.trajectory_class,
    r.trajectory_signal,
    r.intervention_family_label,
    r.intervention_priority_class,
    -- Direction pilier (qualitatif)
    CASE
        WHEN COALESCE(r.trend_slope, 0) >  0.003 THEN 'STRONG_IMPROVEMENT'
        WHEN COALESCE(r.trend_slope, 0) >  0.001 THEN 'IMPROVEMENT'
        WHEN COALESCE(r.trend_slope, 0) >= -0.001 THEN 'STABLE'
        WHEN COALESCE(r.trend_slope, 0) >= -0.003 THEN 'DETERIORATION'
        ELSE                                           'STRONG_DETERIORATION'
    END                                             AS pillar_direction,
    p.nb_indicators_observed,
    'Subscribe for pillar scores, slopes and '
    'sovereign action recommendations.'             AS affiliation_call,
    'OSA Observatory -- CC-BY-4.0'                 AS source
FROM ma.v_isa_observed_scores_by_pillar p
LEFT JOIN ma.v_p7j_recommendation_engine r
    ON  r.country_iso3 = p.country_iso3
    AND r.year         = p.year
    AND r.pillar_code  = p.pillar_code
WHERE p.publication_status = 'OFFICIAL_CONSOLIDATED'
  AND p.year >= 2020
ORDER BY p.country_iso3, p.year, p.pillar_code;

COMMENT ON VIEW pub.v_isa_pillar_breakdown IS
'Sprint 13 -- Open Data Couche 0 -- Trajectoire par pilier 2020-2024.
Direction qualitative sans score absolu.
Scores disponibles en Couche 1 (affilie standard).
CC-BY-4.0 -- open.osa-observatory.org';

-- ── 4. Catalogue opportunites projets structurants ────────────
-- Donnees d appel : projets a delta+ de souverainete
-- Identifie par P7J pour les piliers CRITICAL ou DECLINING
-- avec potentiel de retournement de trajectoire
CREATE OR REPLACE VIEW pub.v_isa_opportunity_catalog AS
SELECT
    r.country_iso3,
    r.year,
    r.pillar_code,
    r.intervention_family_code,
    r.intervention_family_label,
    r.strategic_objective,
    r.consultation_theme,
    -- Signal de delta potentiel (qualitatif)
    CASE
        WHEN r.trajectory_class = 'CRITICAL'
         AND r.intervention_priority_class = 'PRIORITY_CRITICAL'
        THEN 'HIGH_IMPACT_OPPORTUNITY'
        WHEN r.trajectory_class IN ('CRITICAL', 'DECLINING')
         AND r.intervention_priority_class IN ('PRIORITY_CRITICAL','PRIORITY_HIGH')
        THEN 'SIGNIFICANT_OPPORTUNITY'
        WHEN r.trajectory_class = 'STABLE'
         AND r.intervention_priority_class = 'PRIORITY_HIGH'
        THEN 'UNLOCK_OPPORTUNITY'
        ELSE 'MONITORING_OPPORTUNITY'
    END                                             AS opportunity_class,
    -- Delta qualitatif (pas de chiffre precis -- Couche 1)
    CASE
        WHEN r.trajectory_class = 'CRITICAL'
        THEN 'Strong positive delta achievable -- see feasibility study'
        WHEN r.trajectory_class = 'DECLINING'
        THEN 'Moderate positive delta achievable -- see feasibility study'
        WHEN r.trajectory_class = 'STABLE'
        THEN 'Unlock potential identified -- see feasibility study'
        ELSE 'Consolidation delta achievable'
    END                                             AS delta_potential_label,
    -- Appel a etude de faisabilite
    'This opportunity has been identified by the OSA P7J engine. '
    'Contact OSA for a full feasibility study.'     AS feasibility_call,
    'OSA Observatory -- CC-BY-4.0'                 AS source
FROM ma.v_p7j_recommendation_engine r
WHERE r.year = (SELECT MAX(year) FROM ma.v_p7j_recommendation_engine)
  AND r.trajectory_class IN ('CRITICAL', 'DECLINING', 'STABLE')
  AND r.intervention_priority_class IN
      ('PRIORITY_CRITICAL', 'PRIORITY_HIGH', 'PRIORITY_STANDARD')
ORDER BY
    CASE
        WHEN r.trajectory_class = 'CRITICAL'
         AND r.intervention_priority_class = 'PRIORITY_CRITICAL' THEN 1
        WHEN r.trajectory_class IN ('CRITICAL','DECLINING')
         AND r.intervention_priority_class IN ('PRIORITY_CRITICAL','PRIORITY_HIGH') THEN 2
        WHEN r.trajectory_class = 'STABLE'
         AND r.intervention_priority_class = 'PRIORITY_HIGH' THEN 3
        ELSE 4
    END,
    r.country_iso3, r.pillar_code;

COMMENT ON VIEW pub.v_isa_opportunity_catalog IS
'Sprint 13 -- Open Data -- Catalogue opportunites projets structurants.
Donnees d appel : projets a delta+ de souverainete identifies par P7J.
Direction qualitative uniquement -- scores et deltas precis en Couche 1.
Appel a etude de faisabilite S3 pour analyse approfondie.
CC-BY-4.0 -- open.osa-observatory.org';

-- ── 5. Catalogue open data mis a jour ────────────────────────
CREATE OR REPLACE VIEW pub.v_isa_open_data_catalog AS
SELECT
    'ISA_COUNTRY_LATEST'            AS dataset_code,
    'Sovereign state -- latest'     AS dataset_label,
    'Couche 0'                      AS access_layer,
    54                              AS nb_countries,
    2024                            AS reference_year,
    2020                            AS year_from,
    2024                            AS year_to,
    'pub.v_isa_country_latest'      AS view_name,
    '/opendata/countries/latest'    AS api_endpoint,
    'JSON, CSV'                     AS formats,
    'CC-BY-4.0'                     AS license,
    TRUE                            AS open_access,
    'Trajectory, momentum, AMAR band. No absolute scores.' AS content_note
UNION ALL SELECT
    'ISA_COUNTRY_HISTORY',
    'Sovereign trajectory -- 2020-2024',
    'Couche 0',
    54, 2024, 2020, 2024,
    'pub.v_isa_country_history',
    '/opendata/countries/history',
    'JSON, CSV', 'CC-BY-4.0', TRUE,
    'Annual direction (IMPROVING/STABLE/DETERIORATING). No absolute scores.'
UNION ALL SELECT
    'ISA_PILLAR_BREAKDOWN',
    'Pillar trajectories -- 2020-2024',
    'Couche 0',
    54, 2024, 2020, 2024,
    'pub.v_isa_pillar_breakdown',
    '/opendata/pillars',
    'JSON, CSV', 'CC-BY-4.0', TRUE,
    'Pillar direction and trajectory class. No absolute scores.'
UNION ALL SELECT
    'ISA_OPPORTUNITY_CATALOG',
    'Sovereign development opportunities',
    'Couche 0',
    54, 2024, 2024, 2024,
    'pub.v_isa_opportunity_catalog',
    '/opendata/opportunities',
    'JSON, CSV', 'CC-BY-4.0', TRUE,
    'Structural projects with positive sovereignty delta. Call to feasibility study.'
UNION ALL SELECT
    'ISA_AMAR_ALERTS',
    'Atrocity precursor alerts -- 2020-2024',
    'Couche 0',
    54, 2024, 2020, 2024,
    'mg.v_public_p7i_amar_alerts',
    '/opendata/alerts/amar',
    'JSON, CSV', 'CC-BY-4.0', TRUE,
    'AMAR risk band only. Full scores in affiliated access.'
UNION ALL SELECT
    'ISA_P7J_TRAJECTORIES',
    'Sovereign trajectories P7J -- 2020-2024',
    'Couche 0',
    54, 2024, 2020, 2024,
    'mg.v_public_p7j_recommendations',
    '/opendata/trajectories',
    'JSON, CSV', 'CC-BY-4.0', TRUE,
    'Trajectory class and intervention family. No action details.'
UNION ALL SELECT
    'ISA_METHODOLOGY',
    'ISA v2 methodology documentation',
    'Couche 0',
    NULL, NULL, NULL, NULL,
    'pub.v_isa_public_methodology',
    '/opendata/methodology',
    'JSON', 'CC-BY-4.0', TRUE,
    'Full methodology -- open science.'
UNION ALL SELECT
    'ISA_SCORES_FULL',
    'Full ISA scores + slopes + actions',
    'Couche 1',
    54, 2024, 2020, 2024,
    'ma.v_p7j_recommendation_engine',
    '/api/v1/countries/{iso3}/pillars',
    'JSON', 'Proprietary', FALSE,
    'Standard affiliation required. Includes absolute scores and trend slopes.'
UNION ALL SELECT
    'ISA_SIMULATIONS',
    'Predictive scenarios + confidence intervals',
    'Couche 2',
    54, 2024, 2020, 2024,
    'ma.v_p7j_recommendation_engine',
    '/api/v1/predictive/{iso3}',
    'JSON', 'Proprietary', FALSE,
    'Premium affiliation required. CENTRAL/STRESS scenarios + IC P5-P95.';

COMMENT ON VIEW pub.v_isa_open_data_catalog IS
'Sprint 13 -- Catalogue complet datasets OSA -- 3 couches.
Couche 0 : 7 datasets open (CC-BY-4.0).
Couche 1 : scores complets (affilie standard).
Couche 2 : simulations + IC (affilie premium).';

COMMIT;
