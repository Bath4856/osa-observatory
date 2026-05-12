-- ============================================================
-- OSA / ISA — P7E
-- View: ma.v_isa_observed_publication_engine
-- Purpose:
--   Observed publication engine.
--   Joins observed indicator values with P7D dynamic score logic.
--
-- Strict source contracts:
--   ma.indicator_values_final:
--     country_iso3, year, indicator_code, processed_value,
--     country_iso3, year, indicator_code, processed_value, confidence_score
--   Optional columns deliberately NOT required here:
--     is_estimated, quality_flag
--   They are emitted as safe defaults because current ma.indicator_values_final
--   does not expose them in the validated source contract.
--
--   ma.v_dynamic_scores_engine:
--     indicator_code, pillar_code, semantic_code,
--     dynamic_isa_score_component,
--     dynamic_sovereignty_score_component,
--     dynamic_vulnerability_score_component,
--     dynamic_resilience_score_component,
--     dynamic_forecast_score_component,
--     dynamic_ml_score_component,
--     dynamic_score_class,
--     dynamic_score_decision
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_observed_publication_engine AS

WITH params AS (
    SELECT
        EXTRACT(YEAR FROM CURRENT_DATE)::INT AS current_year,
        (EXTRACT(YEAR FROM CURRENT_DATE)::INT - 6) AS official_start_year,
        (EXTRACT(YEAR FROM CURRENT_DATE)::INT - 2) AS official_end_year,
        (EXTRACT(YEAR FROM CURRENT_DATE)::INT - 1) AS provisional_year,
        EXTRACT(YEAR FROM CURRENT_DATE)::INT AS monitoring_year
),
observed_values AS (
    SELECT
        v.country_iso3,
        v.year::INT AS year,
        v.indicator_code,
        COALESCE(v.processed_value, 0)::NUMERIC AS observed_value,
        COALESCE(v.confidence_score, 0)::NUMERIC AS observation_confidence,
        FALSE::BOOLEAN AS is_estimated,
        'OBSERVED_NO_QUALITY_FLAG'::TEXT AS quality_flag
    FROM ma.indicator_values_final v
    WHERE v.country_iso3 IS NOT NULL
      AND v.year IS NOT NULL
      AND v.indicator_code IS NOT NULL
),
score_logic AS (
    SELECT
        s.indicator_code,
        s.pillar_code,
        s.semantic_code,
        COALESCE(s.dynamic_isa_score_component, 0)::NUMERIC AS dynamic_isa_score_component,
        COALESCE(s.dynamic_sovereignty_score_component, 0)::NUMERIC AS dynamic_sovereignty_score_component,
        COALESCE(s.dynamic_vulnerability_score_component, 0)::NUMERIC AS dynamic_vulnerability_score_component,
        COALESCE(s.dynamic_resilience_score_component, 0)::NUMERIC AS dynamic_resilience_score_component,
        COALESCE(s.dynamic_forecast_score_component, 0)::NUMERIC AS dynamic_forecast_score_component,
        COALESCE(s.dynamic_ml_score_component, 0)::NUMERIC AS dynamic_ml_score_component,
        s.dynamic_score_class,
        s.dynamic_score_decision
    FROM ma.v_dynamic_scores_engine s
),
joined AS (
    SELECT
        o.country_iso3,
        COALESCE(r.region_code, 'UNSPECIFIED')::VARCHAR(80) AS region_code,
        COALESCE(r.economic_region_code, 'UNSPECIFIED')::VARCHAR(80) AS economic_region_code,
        COALESCE(r.region_label, r.region_code, 'Unspecified')::TEXT AS region_label,
        COALESCE(r.economic_region_label, r.economic_region_code, 'Unspecified')::TEXT AS economic_region_label,
        o.year,
        s.pillar_code,
        o.indicator_code,
        s.semantic_code,
        o.observed_value,
        o.observation_confidence,
        o.is_estimated,
        o.quality_flag,
        s.dynamic_isa_score_component,
        s.dynamic_sovereignty_score_component,
        s.dynamic_vulnerability_score_component,
        s.dynamic_resilience_score_component,
        s.dynamic_forecast_score_component,
        s.dynamic_ml_score_component,
        s.dynamic_score_class,
        s.dynamic_score_decision,
        CASE
            WHEN o.quality_flag IN ('KO','ERROR','INVALID','EXCLUDED') THEN 0::NUMERIC
            WHEN o.is_estimated THEN 0.75::NUMERIC
            ELSE 1.00::NUMERIC
        END AS observation_quality_factor
    FROM observed_values o
    JOIN score_logic s
      ON s.indicator_code = o.indicator_code
    LEFT JOIN rf.isa_country_region_override r
      ON r.country_iso3 = o.country_iso3
),
scored AS (
    SELECT
        j.*,
        GREATEST(0::NUMERIC, LEAST(1.5::NUMERIC,
            j.observed_value * j.dynamic_isa_score_component * j.observation_confidence * j.observation_quality_factor
        )) AS observed_isa_component,
        GREATEST(0::NUMERIC, LEAST(1.5::NUMERIC,
            j.observed_value * j.dynamic_sovereignty_score_component * j.observation_confidence * j.observation_quality_factor
        )) AS observed_sovereignty_component,
        GREATEST(0::NUMERIC, LEAST(1.5::NUMERIC,
            j.observed_value * j.dynamic_vulnerability_score_component * j.observation_confidence * j.observation_quality_factor
        )) AS observed_vulnerability_component,
        GREATEST(0::NUMERIC, LEAST(1.5::NUMERIC,
            j.observed_value * j.dynamic_resilience_score_component * j.observation_confidence * j.observation_quality_factor
        )) AS observed_resilience_component,
        GREATEST(0::NUMERIC, LEAST(1.5::NUMERIC,
            j.observed_value * j.dynamic_forecast_score_component * j.observation_confidence * j.observation_quality_factor
        )) AS observed_forecast_component,
        GREATEST(0::NUMERIC, LEAST(1.5::NUMERIC,
            j.observed_value * j.dynamic_ml_score_component * j.observation_confidence * j.observation_quality_factor
        )) AS observed_ml_component,
        CASE
            WHEN j.quality_flag IN ('KO','ERROR','INVALID','EXCLUDED') THEN 0
            ELSE 1
        END AS valid_observation_flag,
        CASE WHEN j.is_estimated THEN 1 ELSE 0 END AS estimated_observation_flag
    FROM joined j
),
publication AS (
    SELECT
        s.*,
        CASE
            WHEN s.valid_observation_flag = 0 THEN 'NO_OBSERVED_DATA'
            WHEN s.year BETWEEN p.official_start_year AND p.official_end_year THEN 'OFFICIAL_CONSOLIDATED'
            WHEN s.year = p.provisional_year THEN 'PROVISIONAL_N1'
            WHEN s.year = p.monitoring_year THEN 'CURRENT_YEAR_MONITORING'
            ELSE 'EXCLUDED_NOT_READY'
        END AS publication_status,
        CASE
            WHEN s.year BETWEEN p.official_start_year AND p.official_end_year THEN
                p.official_start_year::TEXT || '-' || p.official_end_year::TEXT
            WHEN s.year = p.provisional_year THEN p.provisional_year::TEXT || '_PROVISIONAL'
            WHEN s.year = p.monitoring_year THEN p.monitoring_year::TEXT || '_MONITORING'
            ELSE 'OUT_OF_PUBLICATION_WINDOW'
        END AS publication_cycle,
        'ISA_P7E_V1'::VARCHAR(40) AS methodology_version,
        CASE
            WHEN s.valid_observation_flag = 0 THEN 'NOT_CERTIFIED'
            WHEN s.is_estimated THEN 'OBSERVED_WITH_ESTIMATION'
            WHEN s.observation_confidence >= 0.85 THEN 'OBSERVED_CERTIFIED_HIGH'
            WHEN s.observation_confidence >= 0.65 THEN 'OBSERVED_CERTIFIED_CONTROLLED'
            ELSE 'OBSERVED_LOW_CONFIDENCE'
        END AS certification_status
    FROM scored s
    CROSS JOIN params p
)
SELECT
    country_iso3,
    region_code,
    economic_region_code,
    region_label,
    economic_region_label,
    year,
    pillar_code,
    indicator_code,
    semantic_code,
    observed_value,
    observation_confidence,
    is_estimated,
    quality_flag,
    observation_quality_factor,
    valid_observation_flag,
    estimated_observation_flag,
    dynamic_isa_score_component,
    dynamic_sovereignty_score_component,
    dynamic_vulnerability_score_component,
    dynamic_resilience_score_component,
    dynamic_forecast_score_component,
    dynamic_ml_score_component,
    observed_isa_component,
    observed_sovereignty_component,
    observed_vulnerability_component,
    observed_resilience_component,
    observed_forecast_component,
    observed_ml_component,
    dynamic_score_class,
    dynamic_score_decision,
    publication_status,
    publication_cycle,
    methodology_version,
    certification_status
FROM publication;
