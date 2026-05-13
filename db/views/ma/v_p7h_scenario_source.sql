CREATE OR REPLACE VIEW ma.v_p7h_scenario_source AS
SELECT
    f.country_iso3::TEXT AS country_iso3,
    f.year::INT AS year,
    f.pillar_code::TEXT AS pillar_code,
    COALESCE(f.publication_status, 'UNKNOWN')::TEXT AS publication_status,
    COALESCE(f.publication_decision, 'UNKNOWN')::TEXT AS publication_decision,
    COALESCE(f.isa_observed_score, 0)::NUMERIC AS isa_observed_score,
    COALESCE(f.sovereignty_observed_score, 0)::NUMERIC AS sovereignty_observed_score,
    COALESCE(f.vulnerability_observed_score, 0)::NUMERIC AS vulnerability_observed_score,
    COALESCE(f.resilience_observed_score, 0)::NUMERIC AS resilience_observed_score,
    COALESCE(f.data_completeness, 0)::NUMERIC AS data_completeness,
    COALESCE(f.observation_confidence, 0)::NUMERIC AS observation_confidence,
    COALESCE(f.weakness_score, 0)::NUMERIC AS weakness_score,
    COALESCE(f.threat_score, 0)::NUMERIC AS threat_score,
    COALESCE(f.strength_score, 0)::NUMERIC AS strength_score,
    COALESCE(f.opportunity_score, 0)::NUMERIC AS opportunity_score,
    COALESCE(f.strategic_risk_score, 0)::NUMERIC AS strategic_risk_score,
    COALESCE(f.strategic_upside_score, 0)::NUMERIC AS strategic_upside_score,
    COALESCE(f.diagnostic_priority_score, 0)::NUMERIC AS diagnostic_priority_score,
    COALESCE(f.strategic_diagnostic_role, 'OBSERVATION_TO_MONITOR')::TEXT AS strategic_diagnostic_role,
    COALESCE(f.strategic_attention_class, 'DIAGNOSTIC_MONITORING')::TEXT AS strategic_attention_class,
    COALESCE(g.forecast_policy_code, 'NO_FORECAST')::TEXT AS forecast_policy_code,
    COALESCE(g.forecast_trend_status, 'FORECAST_REVIEW_REQUIRED')::TEXT AS forecast_trend_status,
    COALESCE(g.forecast_blocking_reason, 'UNKNOWN')::TEXT AS forecast_blocking_reason,
    COALESCE(g.forecast_trend_class, 'STABLE')::TEXT AS forecast_trend_class,
    COALESCE(g.isa_trend_slope, 0)::NUMERIC AS isa_trend_slope,
    COALESCE(g.isa_volatility, 0)::NUMERIC AS isa_volatility,
    COALESCE(g.avg_forecast_readiness_score, 0)::NUMERIC AS avg_forecast_readiness_score,
    COALESCE(g.avg_ml_readiness_score, 0)::NUMERIC AS avg_ml_readiness_score
FROM ma.v_isa_strategic_diagnostic_engine f
LEFT JOIN ma.v_isa_forecast_trend_engine g
  ON g.country_iso3 = f.country_iso3::TEXT
 AND g.pillar_code = f.pillar_code::TEXT;
