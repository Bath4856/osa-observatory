-- ============================================================
-- OSA / ISA — P7G
-- View: ma.v_p7g_forecast_source
-- Purpose:
--   Safe source view for P7G forecasts.
--
-- Depends on:
--   ma.v_isa_observed_scores_by_pillar
--   ma.v_isa_strategic_diagnostic_engine
--
-- Grain:
--   country_iso3, year, pillar_code
-- ============================================================

CREATE OR REPLACE VIEW ma.v_p7g_forecast_source AS
WITH observed AS (
    SELECT
        country_iso3::TEXT AS country_iso3,
        year::INT AS year,
        pillar_code::TEXT AS pillar_code,
        COALESCE(publication_status, 'UNKNOWN')::TEXT AS publication_status,
        COALESCE(publication_decision, 'UNKNOWN')::TEXT AS publication_decision,
        COALESCE(methodology_version, 'UNKNOWN')::TEXT AS methodology_version,
        COALESCE(data_completeness, 0)::NUMERIC AS data_completeness,
        COALESCE(avg_observation_confidence, 0)::NUMERIC AS observation_confidence,
        COALESCE(isa_observed_score, 0)::NUMERIC AS isa_observed_score,
        COALESCE(sovereignty_observed_score, 0)::NUMERIC AS sovereignty_observed_score,
        COALESCE(vulnerability_observed_score, 0)::NUMERIC AS vulnerability_observed_score,
        COALESCE(resilience_observed_score, 0)::NUMERIC AS resilience_observed_score,
        COALESCE(forecast_readiness_score, 0)::NUMERIC AS forecast_readiness_score,
        COALESCE(ml_readiness_score, 0)::NUMERIC AS ml_readiness_score
    FROM ma.v_isa_observed_scores_by_pillar
),
diagnostic AS (
    SELECT
        country_iso3::TEXT AS country_iso3,
        year::INT AS year,
        pillar_code::TEXT AS pillar_code,
        COALESCE(strategic_diagnostic_role, 'OBSERVATION_TO_MONITOR')::TEXT AS strategic_diagnostic_role,
        COALESCE(strategic_attention_class, 'DIAGNOSTIC_MONITORING')::TEXT AS strategic_attention_class,
        COALESCE(diagnostic_priority_score, 0)::NUMERIC AS diagnostic_priority_score,
        COALESCE(strategic_risk_score, 0)::NUMERIC AS strategic_risk_score,
        COALESCE(strategic_upside_score, 0)::NUMERIC AS strategic_upside_score,
        COALESCE(weakness_score, 0)::NUMERIC AS weakness_score,
        COALESCE(threat_score, 0)::NUMERIC AS threat_score,
        COALESCE(strength_score, 0)::NUMERIC AS strength_score,
        COALESCE(opportunity_score, 0)::NUMERIC AS opportunity_score,
        COALESCE(swot_data_status, 'NO_COMPUTED_SWOT_ATTACHED')::TEXT AS swot_data_status
    FROM ma.v_isa_strategic_diagnostic_engine
)
SELECT
    o.country_iso3,
    o.year,
    o.pillar_code,
    o.publication_status,
    o.publication_decision,
    o.methodology_version,
    o.data_completeness,
    o.observation_confidence,
    o.isa_observed_score,
    o.sovereignty_observed_score,
    o.vulnerability_observed_score,
    o.resilience_observed_score,
    o.forecast_readiness_score,
    o.ml_readiness_score,
    COALESCE(d.strategic_diagnostic_role, 'OBSERVATION_TO_MONITOR') AS strategic_diagnostic_role,
    COALESCE(d.strategic_attention_class, 'DIAGNOSTIC_MONITORING') AS strategic_attention_class,
    COALESCE(d.diagnostic_priority_score, 0)::NUMERIC AS diagnostic_priority_score,
    COALESCE(d.strategic_risk_score, 0)::NUMERIC AS strategic_risk_score,
    COALESCE(d.strategic_upside_score, 0)::NUMERIC AS strategic_upside_score,
    COALESCE(d.weakness_score, 0)::NUMERIC AS weakness_score,
    COALESCE(d.threat_score, 0)::NUMERIC AS threat_score,
    COALESCE(d.strength_score, 0)::NUMERIC AS strength_score,
    COALESCE(d.opportunity_score, 0)::NUMERIC AS opportunity_score,
    COALESCE(d.swot_data_status, 'NO_COMPUTED_SWOT_ATTACHED') AS swot_data_status
FROM observed o
LEFT JOIN diagnostic d
  ON d.country_iso3 = o.country_iso3
 AND d.year = o.year
 AND d.pillar_code = o.pillar_code;
