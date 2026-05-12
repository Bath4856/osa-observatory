-- ============================================================
-- OSA / ISA — P7E
-- View: ma.v_isa_observed_scores_by_country_year
-- Purpose:
--   Published observed ISA scores by country/year.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_observed_scores_by_country_year AS
WITH agg AS (
    SELECT
        country_iso3,
        region_code,
        economic_region_code,
        region_label,
        economic_region_label,
        year,
        publication_status,
        publication_cycle,
        methodology_version,
        COUNT(DISTINCT pillar_code) AS nb_pillars_observed,
        SUM(nb_indicators_observed) AS nb_indicators_observed,
        SUM(nb_valid_observations) AS nb_valid_observations,
        SUM(nb_estimated_observations) AS nb_estimated_observations,
        ROUND(AVG(avg_observation_confidence)::NUMERIC, 3) AS avg_observation_confidence,
        ROUND(AVG(data_completeness)::NUMERIC, 3) AS data_completeness,
        ROUND(AVG(isa_observed_score)::NUMERIC, 3) AS isa_observed_score,
        ROUND(AVG(sovereignty_observed_score)::NUMERIC, 3) AS sovereignty_observed_score,
        ROUND(AVG(vulnerability_observed_score)::NUMERIC, 3) AS vulnerability_observed_score,
        ROUND(AVG(resilience_observed_score)::NUMERIC, 3) AS resilience_observed_score,
        ROUND(AVG(forecast_readiness_score)::NUMERIC, 3) AS forecast_readiness_score,
        ROUND(AVG(ml_readiness_score)::NUMERIC, 3) AS ml_readiness_score
    FROM ma.v_isa_observed_scores_by_pillar
    GROUP BY
        country_iso3,
        region_code,
        economic_region_code,
        region_label,
        economic_region_label,
        year,
        publication_status,
        publication_cycle,
        methodology_version
)
SELECT
    *,
    CASE
        WHEN nb_pillars_observed >= 8 AND data_completeness >= 0.70 THEN 'COUNTRY_SCORE_READY'
        WHEN nb_pillars_observed >= 6 AND data_completeness >= 0.50 THEN 'COUNTRY_SCORE_CONTROLLED'
        ELSE 'COUNTRY_SCORE_INCOMPLETE'
    END AS country_score_readiness,
    CASE
        WHEN publication_status = 'OFFICIAL_CONSOLIDATED' AND nb_pillars_observed >= 8 AND data_completeness >= 0.70 THEN 'PUBLISH_OFFICIAL'
        WHEN publication_status = 'PROVISIONAL_N1' THEN 'PUBLISH_PROVISIONAL_WITH_WARNING'
        WHEN publication_status = 'CURRENT_YEAR_MONITORING' THEN 'MONITOR_ONLY'
        ELSE 'DO_NOT_PUBLISH'
    END AS publication_decision
FROM agg;
