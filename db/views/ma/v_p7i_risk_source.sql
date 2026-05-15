/* P7I source: P7F diagnostics + P7G forecast trend + P7H scenarios */
CREATE OR REPLACE VIEW ma.v_p7i_risk_source AS
WITH scenario_agg AS (
    SELECT
        country_iso3::TEXT AS country_iso3,
        year::INT AS year,
        pillar_code::TEXT AS pillar_code,
        MAX(CASE WHEN scenario_code = 'CENTRAL' THEN simulated_isa_delta END)::NUMERIC AS central_isa_delta,
        MAX(CASE WHEN scenario_code = 'AMBITIOUS' THEN simulated_isa_delta END)::NUMERIC AS ambitious_isa_delta,
        MAX(CASE WHEN scenario_code = 'STRESS' THEN simulated_isa_delta END)::NUMERIC AS stress_isa_delta,
        MAX(CASE WHEN scenario_code = 'CENTRAL' THEN simulation_confidence END)::NUMERIC AS central_simulation_confidence,
        MAX(CASE WHEN scenario_code = 'AMBITIOUS' THEN simulation_confidence END)::NUMERIC AS ambitious_simulation_confidence,
        MAX(CASE WHEN scenario_code = 'STRESS' THEN simulation_confidence END)::NUMERIC AS stress_simulation_confidence,
        MAX(CASE WHEN scenario_code = 'CENTRAL' THEN simulation_decision END)::TEXT AS central_simulation_decision,
        MAX(CASE WHEN scenario_code = 'STRESS' THEN simulation_decision END)::TEXT AS stress_simulation_decision
    FROM ma.v_isa_scenario_simulation_engine
    GROUP BY country_iso3, year, pillar_code
)
SELECT
    d.country_iso3::TEXT AS country_iso3,
    d.year::INT AS year,
    d.pillar_code::TEXT AS pillar_code,
    d.publication_status::TEXT AS publication_status,
    d.publication_decision::TEXT AS publication_decision,
    COALESCE(d.isa_observed_score, 0)::NUMERIC AS isa_observed_score,
    COALESCE(d.sovereignty_observed_score, 0)::NUMERIC AS sovereignty_observed_score,
    COALESCE(d.vulnerability_observed_score, 0)::NUMERIC AS vulnerability_observed_score,
    COALESCE(d.resilience_observed_score, 0)::NUMERIC AS resilience_observed_score,
    COALESCE(d.data_completeness, 0)::NUMERIC AS data_completeness,
    COALESCE(d.observation_confidence, 0)::NUMERIC AS observation_confidence,
    COALESCE(d.weakness_score, 0)::NUMERIC AS weakness_score,
    COALESCE(d.threat_score, 0)::NUMERIC AS threat_score,
    COALESCE(d.strength_score, 0)::NUMERIC AS strength_score,
    COALESCE(d.opportunity_score, 0)::NUMERIC AS opportunity_score,
    COALESCE(d.strategic_risk_score, 0)::NUMERIC AS strategic_risk_score,
    COALESCE(d.strategic_upside_score, 0)::NUMERIC AS strategic_upside_score,
    COALESCE(d.diagnostic_priority_score, 0)::NUMERIC AS diagnostic_priority_score,
    d.strategic_diagnostic_role::TEXT AS strategic_diagnostic_role,
    d.strategic_attention_class::TEXT AS strategic_attention_class,
    d.swot_data_status::TEXT AS swot_data_status,
    COALESCE(t.history_years, 0)::INT AS history_years,
    COALESCE(t.avg_observation_confidence, 0)::NUMERIC AS forecast_observation_confidence,
    COALESCE(t.isa_trend_slope, 0)::NUMERIC AS isa_trend_slope,
    COALESCE(t.isa_volatility, 0)::NUMERIC AS isa_volatility,
    COALESCE(t.forecast_policy_code, 'NO_FORECAST')::TEXT AS forecast_policy_code,
    COALESCE(t.forecast_trend_class, 'UNKNOWN')::TEXT AS forecast_trend_class,
    COALESCE(t.forecast_trend_status, 'FORECAST_REVIEW_REQUIRED')::TEXT AS forecast_trend_status,
    COALESCE(t.forecast_blocking_reason, 'FORECAST_REVIEW_REQUIRED')::TEXT AS forecast_blocking_reason,
    COALESCE(s.central_isa_delta, 0)::NUMERIC AS central_isa_delta,
    COALESCE(s.ambitious_isa_delta, 0)::NUMERIC AS ambitious_isa_delta,
    COALESCE(s.stress_isa_delta, 0)::NUMERIC AS stress_isa_delta,
    COALESCE(s.central_simulation_confidence, 0)::NUMERIC AS central_simulation_confidence,
    COALESCE(s.ambitious_simulation_confidence, 0)::NUMERIC AS ambitious_simulation_confidence,
    COALESCE(s.stress_simulation_confidence, 0)::NUMERIC AS stress_simulation_confidence,
    COALESCE(s.central_simulation_decision, 'SIMULATION_REVIEW_REQUIRED')::TEXT AS central_simulation_decision,
    COALESCE(s.stress_simulation_decision, 'STRESS_REVIEW_REQUIRED')::TEXT AS stress_simulation_decision
FROM ma.v_isa_strategic_diagnostic_engine d
LEFT JOIN ma.v_isa_forecast_trend_engine t
  ON t.country_iso3 = d.country_iso3::TEXT
 AND t.pillar_code = d.pillar_code::TEXT
LEFT JOIN scenario_agg s
  ON s.country_iso3 = d.country_iso3::TEXT
 AND s.year = d.year::INT
 AND s.pillar_code = d.pillar_code::TEXT;
