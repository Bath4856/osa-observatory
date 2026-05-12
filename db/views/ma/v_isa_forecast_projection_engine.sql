-- ============================================================
-- OSA / ISA — P7G
-- View: ma.v_isa_forecast_projection_engine
-- Purpose:
--   Deterministic score forecasts with confidence bands.
--
-- Grain:
--   country_iso3, pillar_code, forecast_year, horizon_years
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_forecast_projection_engine AS
WITH trend AS (
    SELECT *
    FROM ma.v_isa_forecast_trend_engine
),
horizons AS (
    SELECT * FROM rf.isa_forecast_horizon_policy
),
expanded AS (
    SELECT
        t.*,
        h.horizon_code,
        h.horizon_years,
        h.horizon_label,
        h.forecast_usage_scope,
        h.publication_scope,
        (t.last_observed_year + h.horizon_years)::INT AS forecast_year
    FROM trend t
    JOIN horizons h
      ON h.horizon_years > 0
     AND h.horizon_years <= COALESCE(t.long_horizon_years, 0)
),
calc AS (
    SELECT
        e.*,

        -- Base projected ISA, bounded.
        GREATEST(
            0::NUMERIC,
            LEAST(
                1.500::NUMERIC,
                COALESCE(e.last_isa_observed_score,0)
                + COALESCE(e.isa_trend_slope,0) * e.horizon_years
                + (COALESCE(e.avg_strategic_upside_score,0) * 0.015 * e.horizon_years)
                - (COALESCE(e.avg_strategic_risk_score,0) * 0.015 * e.horizon_years)
            )
        )::NUMERIC AS forecast_isa_score,

        GREATEST(
            0::NUMERIC,
            LEAST(
                1.500::NUMERIC,
                COALESCE(e.last_sovereignty_observed_score,0)
                + COALESCE(e.isa_trend_slope,0) * 0.80 * e.horizon_years
                + COALESCE(e.avg_strategic_upside_score,0) * 0.010 * e.horizon_years
                - COALESCE(e.avg_strategic_risk_score,0) * 0.010 * e.horizon_years
            )
        )::NUMERIC AS forecast_sovereignty_score,

        GREATEST(
            0::NUMERIC,
            LEAST(
                1.500::NUMERIC,
                COALESCE(e.last_vulnerability_observed_score,0)
                + COALESCE(e.avg_strategic_risk_score,0) * 0.020 * e.horizon_years
                - COALESCE(e.avg_strategic_upside_score,0) * 0.010 * e.horizon_years
            )
        )::NUMERIC AS forecast_vulnerability_score,

        GREATEST(
            0::NUMERIC,
            LEAST(
                1.500::NUMERIC,
                COALESCE(e.last_resilience_observed_score,0)
                + COALESCE(e.isa_trend_slope,0) * 0.50 * e.horizon_years
                + COALESCE(e.avg_strategic_upside_score,0) * 0.012 * e.horizon_years
            )
        )::NUMERIC AS forecast_resilience_score,

        GREATEST(
            0::NUMERIC,
            LEAST(
                1.000::NUMERIC,
                (
                    COALESCE(e.avg_observation_confidence,0) * 0.35
                  + COALESCE(e.avg_data_completeness,0) * 0.25
                  + COALESCE(e.avg_forecast_readiness_score,0) * 0.25
                  + LEAST(1::NUMERIC, COALESCE(e.history_years,0)::NUMERIC / 5.0) * 0.15
                )
                - (COALESCE(e.isa_volatility,0) * COALESCE(e.uncertainty_multiplier,1.0) * 0.40)
                - (e.horizon_years::NUMERIC * 0.025)
            )
        )::NUMERIC AS forecast_confidence,

        GREATEST(
            0.020::NUMERIC,
            LEAST(
                0.500::NUMERIC,
                (
                    COALESCE(e.isa_volatility,0) * COALESCE(e.uncertainty_multiplier,1.0)
                  + e.horizon_years::NUMERIC * 0.025
                  + (1 - COALESCE(e.avg_observation_confidence,0)) * 0.050
                )
            )
        )::NUMERIC AS forecast_uncertainty
    FROM expanded e
),
bounded AS (
    SELECT
        c.*,
        GREATEST(0::NUMERIC, c.forecast_isa_score - c.forecast_uncertainty)::NUMERIC AS forecast_isa_low,
        LEAST(1.500::NUMERIC, c.forecast_isa_score + c.forecast_uncertainty)::NUMERIC AS forecast_isa_high,
        CASE
            WHEN c.forecast_policy_code = 'NO_FORECAST' THEN 'NO_FORECAST'
            WHEN c.forecast_confidence >= 0.750 THEN 'FORECAST_HIGH_CONFIDENCE'
            WHEN c.forecast_confidence >= 0.600 THEN 'FORECAST_CONTROLLED_CONFIDENCE'
            WHEN c.forecast_confidence >= 0.450 THEN 'FORECAST_LOW_CONFIDENCE'
            ELSE 'FORECAST_REVIEW_REQUIRED'
        END AS forecast_confidence_class,
        CASE
            WHEN c.forecast_policy_code = 'NO_FORECAST' THEN 'DO_NOT_USE_FORECAST'
            WHEN c.forecast_trend_class = 'VOLATILE' THEN 'USE_WITH_VOLATILITY_WARNING'
            WHEN c.forecast_confidence >= COALESCE(c.min_forecast_confidence,0.60) THEN 'USE_AS_PREDICTIVE_SIGNAL'
            WHEN c.forecast_confidence >= 0.450 THEN 'USE_AS_INDICATIVE_SIGNAL'
            ELSE 'REVIEW_BEFORE_USE'
        END AS forecast_decision
    FROM calc c
)
SELECT
    country_iso3,
    pillar_code,
    last_observed_year,
    forecast_year,
    horizon_code,
    horizon_years,
    horizon_label,
    forecast_usage_scope,
    publication_scope,

    history_years,
    first_year,
    avg_data_completeness,
    avg_observation_confidence,

    last_isa_observed_score,
    isa_trend_slope,
    isa_volatility,
    forecast_trend_class,
    forecast_trend_status,
    forecast_warning_level,

    ROUND(forecast_isa_score, 3) AS forecast_isa_score,
    ROUND(forecast_isa_low, 3) AS forecast_isa_low,
    ROUND(forecast_isa_high, 3) AS forecast_isa_high,
    ROUND(forecast_sovereignty_score, 3) AS forecast_sovereignty_score,
    ROUND(forecast_vulnerability_score, 3) AS forecast_vulnerability_score,
    ROUND(forecast_resilience_score, 3) AS forecast_resilience_score,
    ROUND(forecast_confidence, 3) AS forecast_confidence,
    ROUND(forecast_uncertainty, 3) AS forecast_uncertainty,

    forecast_policy_code,
    forecast_policy_label,
    forecast_confidence_class,
    forecast_decision,

    avg_strategic_risk_score,
    avg_strategic_upside_score,
    avg_diagnostic_priority_score
FROM bounded;
