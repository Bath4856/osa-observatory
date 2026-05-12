-- ============================================================
-- OSA / ISA — P7G
-- View: ma.v_isa_forecast_trend_engine
-- Purpose:
--   Build historical deterministic trend features.
--
-- Grain:
--   country_iso3, pillar_code
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_forecast_trend_engine AS
WITH src AS (
    SELECT *
    FROM ma.v_p7g_forecast_source
),
series AS (
    SELECT
        country_iso3,
        pillar_code,
        COUNT(*)::INT AS history_years,
        MIN(year)::INT AS first_year,
        MAX(year)::INT AS last_observed_year,
        AVG(data_completeness)::NUMERIC AS avg_data_completeness,
        AVG(observation_confidence)::NUMERIC AS avg_observation_confidence,

        AVG(isa_observed_score)::NUMERIC AS avg_isa_score,
        AVG(sovereignty_observed_score)::NUMERIC AS avg_sovereignty_score,
        AVG(vulnerability_observed_score)::NUMERIC AS avg_vulnerability_score,
        AVG(resilience_observed_score)::NUMERIC AS avg_resilience_score,
        AVG(forecast_readiness_score)::NUMERIC AS avg_forecast_readiness_score,
        AVG(ml_readiness_score)::NUMERIC AS avg_ml_readiness_score,

        -- Slope approximation: covariance(year, score) / variance(year)
        CASE
            WHEN SUM((year - ybar) * (year - ybar)) = 0 THEN 0
            ELSE SUM((year - ybar) * (isa_observed_score - sbar)) / NULLIF(SUM((year - ybar) * (year - ybar)), 0)
        END::NUMERIC AS isa_trend_slope,

        CASE
            WHEN COUNT(*) <= 1 THEN 0
            ELSE STDDEV_POP(isa_observed_score)
        END::NUMERIC AS isa_volatility,

        MAX(CASE WHEN year = max_year THEN isa_observed_score END)::NUMERIC AS last_isa_observed_score,
        MAX(CASE WHEN year = max_year THEN sovereignty_observed_score END)::NUMERIC AS last_sovereignty_observed_score,
        MAX(CASE WHEN year = max_year THEN vulnerability_observed_score END)::NUMERIC AS last_vulnerability_observed_score,
        MAX(CASE WHEN year = max_year THEN resilience_observed_score END)::NUMERIC AS last_resilience_observed_score,
        MAX(CASE WHEN year = max_year THEN forecast_readiness_score END)::NUMERIC AS last_forecast_readiness_score,
        MAX(CASE WHEN year = max_year THEN ml_readiness_score END)::NUMERIC AS last_ml_readiness_score,

        AVG(strategic_risk_score)::NUMERIC AS avg_strategic_risk_score,
        AVG(strategic_upside_score)::NUMERIC AS avg_strategic_upside_score,
        AVG(diagnostic_priority_score)::NUMERIC AS avg_diagnostic_priority_score
    FROM (
        SELECT
            s.*,
            AVG(year) OVER (PARTITION BY country_iso3, pillar_code) AS ybar,
            AVG(isa_observed_score) OVER (PARTITION BY country_iso3, pillar_code) AS sbar,
            MAX(year) OVER (PARTITION BY country_iso3, pillar_code) AS max_year
        FROM src s
    ) x
    GROUP BY country_iso3, pillar_code
),
classified AS (
    SELECT
        s.*,
        CASE
            WHEN history_years >= 5 AND avg_data_completeness >= 0.700 AND avg_observation_confidence >= 0.600 THEN 'ROBUST_FORECAST'
            WHEN history_years >= 4 AND avg_data_completeness >= 0.600 AND avg_observation_confidence >= 0.500 THEN 'CONTROLLED_FORECAST'
            WHEN history_years >= 3 AND avg_data_completeness >= 0.500 AND avg_observation_confidence >= 0.400 THEN 'LIMITED_FORECAST'
            ELSE 'NO_FORECAST'
        END AS forecast_policy_code,

        CASE
            WHEN ABS(COALESCE(isa_volatility,0)) >= 0.180 THEN 'VOLATILE'
            WHEN COALESCE(isa_trend_slope,0) > 0.010 THEN 'IMPROVING'
            WHEN COALESCE(isa_trend_slope,0) < -0.010 THEN 'DETERIORATING'
            ELSE 'STABLE'
        END AS forecast_trend_class
    FROM series s
)
SELECT
    c.*,
    p.forecast_policy_label,
    p.min_history_years,
    p.min_data_completeness,
    p.min_observation_confidence,
    p.short_horizon_years,
    p.medium_horizon_years,
    p.long_horizon_years,
    p.min_forecast_confidence,
    p.uncertainty_multiplier,
    p.drift_warning_threshold,
    i.trend_label,
    i.recommended_use AS forecast_recommended_use,
    i.warning_level AS forecast_warning_level,
    CASE
        WHEN c.forecast_policy_code = 'NO_FORECAST' THEN 'FORECAST_DISABLED_INSUFFICIENT_HISTORY'
        WHEN c.forecast_trend_class = 'VOLATILE' THEN 'FORECAST_ENABLED_WITH_VOLATILITY_WARNING'
        WHEN c.forecast_policy_code = 'ROBUST_FORECAST' THEN 'FORECAST_READY_ROBUST'
        WHEN c.forecast_policy_code = 'CONTROLLED_FORECAST' THEN 'FORECAST_READY_CONTROLLED'
        ELSE 'FORECAST_LIMITED_INDICATIVE'
    END AS forecast_trend_status
FROM classified c
LEFT JOIN rf.isa_forecast_policy p
  ON p.forecast_policy_code = c.forecast_policy_code
LEFT JOIN rf.isa_forecast_interpretation_policy i
  ON i.trend_class = c.forecast_trend_class;
