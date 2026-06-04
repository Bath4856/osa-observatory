
BEGIN;

-- ============================================================
-- OSA Observatory -- Sprint 20
-- Enrichissement pub.mv_isa_country_scores et pub.mv_isa_pillar_breakdown
-- Resolution timeouts V2_COUNTRY_PROFILE (6.8s) et V2_COUNTRY_PILLARS (71s)
-- ============================================================

-- 1. Enrichir pub.mv_isa_country_scores
DROP MATERIALIZED VIEW pub.mv_isa_country_scores CASCADE;

CREATE MATERIALIZED VIEW pub.mv_isa_country_scores AS
SELECT
    s.country_iso3,
    s.year,
    COALESCE(s.region_code, ca.region_code)             AS region_code,
    COALESCE(s.region_label, rg.name_fr)                AS region_label,
    ROUND(s.isa_observed_score::numeric, 4)             AS isa_observed_score,
    ROUND(s.sovereignty_observed_score::numeric, 4)     AS sovereignty_score,
    ROUND(s.vulnerability_observed_score::numeric, 4)   AS vulnerability_score,
    ROUND(s.resilience_observed_score::numeric, 4)      AS resilience_score,
    ROUND(s.avg_observation_confidence::numeric, 4)     AS data_confidence,
    s.nb_pillars_observed,
    s.nb_indicators_observed,
    s.publication_status,
    s.publication_cycle,
    s.methodology_version
FROM ma.v_isa_observed_scores_by_country_year s
LEFT JOIN rf.v_country_aliases ca ON ca.iso3 = s.country_iso3
LEFT JOIN rf.regions rg ON rg.code = ca.region_code
WHERE s.publication_status = 'OFFICIAL_CONSOLIDATED';

CREATE UNIQUE INDEX idx_mv_country_scores_pk
    ON pub.mv_isa_country_scores (country_iso3, year);
CREATE INDEX idx_mv_country_scores_year
    ON pub.mv_isa_country_scores (year, isa_observed_score DESC);
CREATE INDEX idx_mv_country_scores_iso3
    ON pub.mv_isa_country_scores (country_iso3);

COMMENT ON MATERIALIZED VIEW pub.mv_isa_country_scores IS
    'MV enrichie Sprint 20 -- scores ISA par pays/annee avec colonnes observed. '
    'Remplace ma.v_isa_observed_scores_by_country_year pour countries.py. '
    'Resolution timeout 163s/6.8s -> <10ms.';

-- 2. Enrichir pub.mv_isa_pillar_breakdown
DROP MATERIALIZED VIEW pub.mv_isa_pillar_breakdown CASCADE;

CREATE MATERIALIZED VIEW pub.mv_isa_pillar_breakdown AS
SELECT
    p.country_iso3,
    p.year,
    p.pillar_code,
    COALESCE(p.region_code, ca.region_code)                AS region_code,
    ROUND(p.isa_observed_score::numeric, 4)                AS pillar_isa_score,
    ROUND(p.sovereignty_observed_score::numeric, 4)        AS sovereignty_score,
    ROUND(p.vulnerability_observed_score::numeric, 4)      AS vulnerability_score,
    ROUND(p.avg_observation_confidence::numeric, 4)        AS data_confidence,
    p.nb_indicators_observed,
    p.publication_status,
    -- Trajectoire P7J
    r.trajectory_class,
    r.trajectory_signal,
    ROUND(r.trend_slope::numeric, 5)                       AS trend_slope,
    r.intervention_family_label,
    r.intervention_priority_class,
    ROUND(r.intervention_priority_score::numeric, 4)       AS intervention_priority_score,
    r.recommended_action,
    r.open_data_allowed,
    r.premium_allowed,
    -- Open data fields
    'Request institutional access at open.osa-observatory.org'::text AS affiliation_call,
    'OSA Observatory -- CC-BY-NC-4.0'::text                          AS source
FROM ma.v_isa_observed_scores_by_pillar p
LEFT JOIN ma.v_p7j_recommendation_engine r
    ON  r.country_iso3 = p.country_iso3
    AND r.year         = p.year
    AND r.pillar_code  = p.pillar_code
LEFT JOIN rf.v_country_aliases ca ON ca.iso3 = p.country_iso3
WHERE p.publication_status = 'OFFICIAL_CONSOLIDATED';

CREATE UNIQUE INDEX idx_mv_pillar_pk
    ON pub.mv_isa_pillar_breakdown (country_iso3, year, pillar_code);
CREATE INDEX idx_mv_pillar_country_year
    ON pub.mv_isa_pillar_breakdown (country_iso3, year);
CREATE INDEX idx_mv_pillar_trajectory
    ON pub.mv_isa_pillar_breakdown (trajectory_class, year);

COMMENT ON MATERIALIZED VIEW pub.mv_isa_pillar_breakdown IS
    'MV enrichie Sprint 20 -- scores piliers + trajectoires P7J. '
    'Remplace ma.v_isa_observed_scores_by_pillar + ma.v_p7j_recommendation_engine pour countries.py. '
    'Resolution timeout 71s -> <10ms.';

COMMIT;
