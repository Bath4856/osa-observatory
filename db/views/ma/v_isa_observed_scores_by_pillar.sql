-- ============================================================
-- OSA / ISA — P7E
-- View: ma.v_isa_observed_scores_by_pillar
-- Purpose:
--   Published observed scores by country/year/pillar.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_observed_scores_by_pillar AS
WITH agg AS (
    SELECT
        country_iso3,
        region_code,
        economic_region_code,
        region_label,
        economic_region_label,
        year,
        pillar_code,
        publication_status,
        publication_cycle,
        methodology_version,
        COUNT(*) AS nb_indicators_observed,
        SUM(valid_observation_flag) AS nb_valid_observations,
        SUM(estimated_observation_flag) AS nb_estimated_observations,
        ROUND(AVG(observation_confidence)::NUMERIC, 3) AS avg_observation_confidence,
        ROUND((SUM(valid_observation_flag)::NUMERIC / NULLIF(COUNT(*),0))::NUMERIC, 3) AS data_completeness,
        ROUND(AVG(observed_isa_component)::NUMERIC, 3) AS isa_observed_score,
        ROUND(AVG(observed_sovereignty_component)::NUMERIC, 3) AS sovereignty_observed_score,
        ROUND(AVG(observed_vulnerability_component)::NUMERIC, 3) AS vulnerability_observed_score,
        ROUND(AVG(observed_resilience_component)::NUMERIC, 3) AS resilience_observed_score,
        ROUND(AVG(observed_forecast_component)::NUMERIC, 3) AS forecast_readiness_score,
        ROUND(AVG(observed_ml_component)::NUMERIC, 3) AS ml_readiness_score,
        CASE
            WHEN SUM(valid_observation_flag) = 0 THEN 'NOT_CERTIFIED'
            WHEN AVG(observation_confidence) >= 0.85 AND SUM(estimated_observation_flag) = 0 THEN 'CERTIFIED_OBSERVED_HIGH'
            WHEN AVG(observation_confidence) >= 0.65 THEN 'CERTIFIED_OBSERVED_CONTROLLED'
            ELSE 'LOW_CONFIDENCE_OBSERVED'
        END AS certification_status
    FROM ma.v_isa_observed_publication_engine
    GROUP BY
        country_iso3,
        region_code,
        economic_region_code,
        region_label,
        economic_region_label,
        year,
        pillar_code,
        publication_status,
        publication_cycle,
        methodology_version
)
SELECT
    *,
    CASE
        WHEN publication_status = 'OFFICIAL_CONSOLIDATED' AND data_completeness >= 0.70 THEN 'PUBLISH_OFFICIAL'
        WHEN publication_status = 'PROVISIONAL_N1' THEN 'PUBLISH_PROVISIONAL_WITH_WARNING'
        WHEN publication_status = 'CURRENT_YEAR_MONITORING' THEN 'MONITOR_ONLY'
        ELSE 'DO_NOT_PUBLISH'
    END AS publication_decision,
    CASE
        WHEN publication_status = 'PROVISIONAL_N1' THEN 'Données incomplètes ou en cours de consolidation.'
        WHEN publication_status = 'OFFICIAL_CONSOLIDATED' THEN 'Score officiel consolidé.'
        WHEN publication_status = 'CURRENT_YEAR_MONITORING' THEN 'Année courante en monitoring, non publiée officiellement.'
        ELSE 'Score hors fenêtre de publication.'
    END AS publication_note
FROM agg;
