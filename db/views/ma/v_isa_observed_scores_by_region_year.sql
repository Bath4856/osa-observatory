-- ============================================================
-- OSA / ISA — P7E
-- View: ma.v_isa_observed_scores_by_region_year
-- Purpose:
--   Published observed ISA scores by region/economic region/year.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_observed_scores_by_region_year AS
SELECT
    region_code,
    economic_region_code,
    region_label,
    economic_region_label,
    year,
    publication_status,
    publication_cycle,
    methodology_version,
    COUNT(DISTINCT country_iso3) AS nb_countries,
    ROUND(AVG(data_completeness)::NUMERIC, 3) AS avg_data_completeness,
    ROUND(AVG(isa_observed_score)::NUMERIC, 3) AS isa_observed_score,
    ROUND(AVG(sovereignty_observed_score)::NUMERIC, 3) AS sovereignty_observed_score,
    ROUND(AVG(vulnerability_observed_score)::NUMERIC, 3) AS vulnerability_observed_score,
    ROUND(AVG(resilience_observed_score)::NUMERIC, 3) AS resilience_observed_score,
    ROUND(AVG(forecast_readiness_score)::NUMERIC, 3) AS forecast_readiness_score,
    ROUND(AVG(ml_readiness_score)::NUMERIC, 3) AS ml_readiness_score,
    CASE
        WHEN publication_status = 'OFFICIAL_CONSOLIDATED' THEN 'PUBLISH_OFFICIAL_REGION'
        WHEN publication_status = 'PROVISIONAL_N1' THEN 'PUBLISH_PROVISIONAL_REGION_WITH_WARNING'
        WHEN publication_status = 'CURRENT_YEAR_MONITORING' THEN 'MONITOR_REGION_ONLY'
        ELSE 'DO_NOT_PUBLISH_REGION'
    END AS publication_decision
FROM ma.v_isa_observed_scores_by_country_year
GROUP BY
    region_code,
    economic_region_code,
    region_label,
    economic_region_label,
    year,
    publication_status,
    publication_cycle,
    methodology_version;
